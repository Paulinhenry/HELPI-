const app = require('./app');
const http = require('http');
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const logger = require('./utils/logger');
const { TAXA_DESLOCAMENTO } = require('./utils/constants');

const PORT = process.env.PORT || 3000;

// 1. Criamos o servidor HTTP e anexamos o Socket.io a ele
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: true, // Reflete a origem exata do request
        methods: ["GET", "POST", "PATCH"],
        credentials: true,
    }
});

const pool = require('./config/database');

// 2. O RADAR DE PROFISSIONAIS ONLINE
// Este "Map" guarda na memória do servidor quem está online.
// Chave: ID do Profissional | Valor: ID do Socket do telemóvel dele
const profissionaisConectados = new Map();

// =============================================================
// SEGURANÇA: Autenticação JWT no handshake do Socket.IO
// Impede que qualquer cliente WebSocket se faça passar por outro usuário.
// =============================================================
io.use((socket, next) => {
    try {
        const token = socket.handshake.auth?.token ||
                      socket.handshake.headers?.authorization?.replace('Bearer ', '');

        if (!token) {
            // SEGURANÇA V3: Rejeita conexões sem token (previne DoS e enumeração)
            return next(new Error('Autenticação obrigatória. Envie um token JWT válido.'));
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.decoded = decoded; // { id, tipo } — disponível em todos os eventos
        next();
    } catch (err) {
        // SEGURANÇA V3: Token inválido = conexão rejeitada
        return next(new Error('Token inválido ou expirado.'));
    }
});

io.on('connection', (socket) => {
    logger.info(`[SOCKET] CONEXÃO: novo dispositivo conectado (socket_id: ${socket.id})`);

    // Quando o app do cliente conecta, junta-se à sala do cliente para receber notificações
    socket.on('entrar_sala_cliente', (dados) => {
        // SEGURANÇA: Valida que o cliente só entra na sua própria sala
        const cliente_id = socket.decoded?.tipo === 'cliente' ? socket.decoded.id : null;
        if (cliente_id) {
            socket.join(`cliente:${cliente_id}`);
            logger.info(`[SOCKET] SALA_CLIENTE: cliente ${cliente_id} entrou na sala de notificações`);
        } else {
            logger.warn(`[SOCKET] SALA_CLIENTE_NEGADA: tentativa sem token válido (socket: ${socket.id})`);
        }
    });

    // Quando o telemóvel do trabalhador abrir a app e clicar "Estou online!"
    socket.on('ficar_online', async (dados) => {
        try {
            // SEGURANÇA: ID vem do JWT verificado no handshake, não do payload do cliente
            if (!socket.decoded || socket.decoded.tipo !== 'profissional') {
                logger.warn(`[RADAR] ONLINE_NEGADO: socket sem token de profissional válido (socket: ${socket.id})`);
                return;
            }
            const profissional_id = socket.decoded.id;
            const { latitude, longitude } = dados;

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
                // SEGURANÇA: Query totalmente parametrizada — sem template literals.
                // Antes usava interpolação de MAPA_CATEGORIAS diretamente na SQL (SQL injection potencial).
                const queryChamados = `
                    SELECT c.id, c.categoria_solicitada, c.problema_descricao,
                           ST_Distance(
                               ST_SetSRID(ST_MakePoint(c.longitude_destino, c.latitude_destino), 4326)::geography,
                               ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
                           ) / 1000 AS distancia_km
                    FROM chamados_express c
                    CROSS JOIN (SELECT categoria FROM profissionais WHERE id = $3) p
                    WHERE c.status = 'procurando_profissional'
                      AND LOWER(c.categoria_solicitada) = LOWER(p.categoria)
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
    socket.on('atualizar_localizacao', async (dados) => {
        // SEGURANÇA: ID vem do JWT, não do payload
        if (!socket.decoded || socket.decoded.tipo !== 'profissional') return;
        const profissional_id = socket.decoded.id;
        const { latitude, longitude, cliente_id } = dados;
        
        if (latitude && longitude && cliente_id) {
            // SEGURANÇA V4: Valida que o cliente_id pertence a um chamado ativo deste profissional
            // Previne que um profissional envie localização para a sala de outro cliente
            try {
                const chamadoAtivo = await pool.query(
                    `SELECT id FROM chamados_express
                     WHERE profissional_id = $1 AND cliente_id = $2 AND status IN ('a_caminho', 'em_servico')
                     LIMIT 1`,
                    [profissional_id, cliente_id]
                );
                if (chamadoAtivo.rows.length === 0) {
                    logger.warn(`[RADAR] LOCALIZACAO_NEGADA: profissional ${profissional_id} tentou enviar coords para cliente ${cliente_id} sem chamado ativo`);
                    return;
                }
            } catch (err) {
                logger.error(`[RADAR] ERRO_VALIDACAO_LOC: ${err.message}`);
                return;
            }

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
    const isProd = process.env.NODE_ENV === 'production';
    const serverUrl = isProd ? 'https://helpi-api.onrender.com' : `http://localhost:${PORT}`;
    logger.info(`[SERVER] INICIALIZADO: servidor HTTP + WebSocket rodando em ${serverUrl} (env: ${process.env.NODE_ENV || 'development'})`);
});