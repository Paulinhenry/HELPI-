const app = require('./app');
const http = require('http');
const { Server } = require('socket.io');
const logger = require('./utils/logger');
const { TAXA_DESLOCAMENTO, MAPA_CATEGORIAS } = require('./utils/constants');

const PORT = process.env.PORT || 3000;

// Configuração de CORS por ambiente (igual ao Express)
const corsOrigins = process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(',').map(o => o.trim())
    : ['*'];

// 1. Criamos o servidor HTTP e anexamos o Socket.io a ele
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: process.env.NODE_ENV === 'production' ? corsOrigins : '*',
        methods: ["GET", "POST", "PATCH"]
    }
});

const pool = require('./config/database');

// 2. O RADAR DE PROFISSIONAIS ONLINE
// Este "Map" guarda na memória do servidor quem está online.
// Chave: ID do Profissional | Valor: ID do Socket do telemóvel dele
const profissionaisConectados = new Map();

io.on('connection', (socket) => {
    logger.info(`[SOCKET] CONEXÃO: novo dispositivo conectado (socket_id: ${socket.id})`);

    // Quando o app do cliente conecta, junta-se à sala do cliente para receber notificações
    socket.on('entrar_sala_cliente', (dados) => {
        const { cliente_id } = dados;
        if (cliente_id) {
            socket.join(`cliente:${cliente_id}`);
            logger.info(`[SOCKET] SALA_CLIENTE: cliente ${cliente_id} entrou na sala de notificações`);
        }
    });

    // Quando o telemóvel do trabalhador abrir a app e clicar "Estou online!"
    socket.on('ficar_online', async (dados) => {
        try {
            const { profissional_id, latitude, longitude } = dados;

            // CORREÇÃO: Limpa socket antigo se o profissional reconectar com novo socket
            const socketAntigo = profissionaisConectados.get(profissional_id);
            if (socketAntigo && socketAntigo !== socket.id) {
                logger.info(`[RADAR] RECONEXÃO: profissional ${profissional_id} reconectou (socket_antigo: ${socketAntigo}, socket_novo: ${socket.id})`);
            }

            profissionaisConectados.set(profissional_id, socket.id);
            
            // Atualiza o status e as coordenadas do GPS na Base de Dados para o PostGIS conseguir encontrá-lo
            if (latitude && longitude) {
                await pool.query(
                    `UPDATE profissionais 
                     SET is_online = true, 
                         coordenadas = ST_SetSRID(ST_MakePoint($1, $2), 4326) 
                     WHERE id = $3`,
                    [longitude, latitude, profissional_id] // O PostGIS usa Longitude primeiro (X, Y)
                );
            } else {
                // Apenas muda o status se não enviar GPS
                await pool.query('UPDATE profissionais SET is_online = true WHERE id = $1', [profissional_id]);
            }
            
            logger.info(`[RADAR] ONLINE: profissional ${profissional_id} ficou online (lat: ${latitude}, lng: ${longitude})`);

            // --- NOVO: VERIFICAR CHAMADOS PENDENTES QUE ELE PERDEU ---
            if (latitude && longitude) {
                const queryChamados = `
                    SELECT c.id, c.categoria_solicitada, c.problema_descricao,
                           ST_Distance(
                               ST_SetSRID(ST_MakePoint(c.longitude_destino, c.latitude_destino), 4326)::geography,
                               ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
                           ) / 1000 AS distancia_km
                    FROM chamados_express c
                    CROSS JOIN (SELECT categoria FROM profissionais WHERE id = $3) p
                    WHERE c.status = 'procurando_profissional'
                      AND (
                          (p.categoria = '${MAPA_CATEGORIAS['Elétrica']}' AND LOWER(c.categoria_solicitada) = 'elétrica') OR
                          (p.categoria = '${MAPA_CATEGORIAS['Hidráulica']}' AND LOWER(c.categoria_solicitada) = 'hidráulica') OR
                          (p.categoria = '${MAPA_CATEGORIAS['Chaveiro']}' AND LOWER(c.categoria_solicitada) = 'chaveiro') OR
                          (p.categoria = '${MAPA_CATEGORIAS['Limpeza']}' AND LOWER(c.categoria_solicitada) = 'limpeza') OR
                          (p.categoria = '${MAPA_CATEGORIAS['Montador']}' AND LOWER(c.categoria_solicitada) = 'montador') OR
                          (LOWER(c.categoria_solicitada) = LOWER(p.categoria))
                      )
                      AND ST_DWithin(
                          ST_SetSRID(ST_MakePoint(c.longitude_destino, c.latitude_destino), 4326)::geography,
                          ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
                          10000
                      )
                `;
                const { rows: chamadosAtivos } = await pool.query(queryChamados, [longitude, latitude, profissional_id]);
                
                if (chamadosAtivos.length > 0) {
                    logger.info(`[RADAR] CHAMADOS_PENDENTES: ${chamadosAtivos.length} chamado(s) reenviado(s) para profissional ${profissional_id}`);
                    chamadosAtivos.forEach(chamado => {
                        socket.emit('novo_chamado_emergencia', {
                            chamado_id: chamado.id,
                            categoria: chamado.categoria_solicitada,
                            descricao: chamado.problema_descricao,
                            distancia_metros: Math.round(chamado.distancia_km * 1000),
                            valor_sugerido: TAXA_DESLOCAMENTO
                        });
                    });
                }
            }
        } catch (error) {
            logger.error(`[RADAR] ERRO_ONLINE: falha ao colocar profissional online`, { error: error.message, stack: error.stack });
        }
    });

    // --- NOVO: RECEBER LOCALIZAÇÃO DO PROFISSIONAL EM TEMPO REAL ---
    socket.on('atualizar_localizacao', (dados) => {
        const { profissional_id, latitude, longitude, cliente_id } = dados;
        
        if (latitude && longitude && cliente_id) {
            // Emite a localização do profissional apenas para o cliente do chamado ativo
            io.to(`cliente:${cliente_id}`).emit('localizacao_profissional', {
                profissional_id,
                latitude,
                longitude,
                timestamp: new Date().toISOString()
            });
            logger.info(`[RADAR] LOCALIZACAO_LIVE: profissional ${profissional_id} enviou coords lat: ${latitude}, lng: ${longitude} p/ cliente ${cliente_id}`);
        }
    });

    // Quando o trabalhador fechar a app, ficar sem internet ou clicar "Ficar Offline"
    socket.on('disconnect', async () => {
        for (let [id, socketId] of profissionaisConectados.entries()) {
            if (socketId === socket.id) {
                profissionaisConectados.delete(id);
                
                try {
                    // Proteção de segurança: marca como offline na base de dados automaticamente
                    await pool.query('UPDATE profissionais SET is_online = false WHERE id = $1', [id]);
                } catch (error) {
                    logger.error(`[RADAR] ERRO_OFFLINE: falha ao marcar profissional ${id} como offline`, { error: error.message });
                }

                logger.info(`[RADAR] OFFLINE: profissional ${id} desconectou`);
                break;
            }
        }
    });
});

// 3. Injetamos o "io" e a lista de online no Express para os Controllers usarem
app.set('io', io);
app.set('profissionaisConectados', profissionaisConectados);

// 4. Arrancamos o servidor
server.listen(PORT, () => {
    logger.info(`[SERVER] INICIALIZADO: servidor HTTP + WebSocket a correr na porta ${PORT} (env: ${process.env.NODE_ENV || 'development'})`);
});