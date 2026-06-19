const app = require('./app');
const http = require('http');
const { Server } = require('socket.io');

const PORT = process.env.PORT || 3000;

// 1. Criamos o servidor HTTP e anexamos o Socket.io a ele
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*", // Permite conexões de qualquer app
        methods: ["GET", "POST", "PATCH"]
    }
});

const pool = require('./config/database');

// 2. O RADAR DE PROFISSIONAIS ONLINE
// Este "Map" guarda na memória do servidor quem está online.
// Chave: ID do Profissional | Valor: ID do Socket do telemóvel dele
const profissionaisConectados = new Map();

io.on('connection', (socket) => {
    console.log(`[Socket.io] 🟢 Novo dispositivo conectado: ${socket.id}`);

    // Quando o telemóvel do trabalhador abrir a app e clicar "Estou online!"
    socket.on('ficar_online', async (dados) => {
        try {
            const { profissional_id, latitude, longitude } = dados;
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
            
            console.log(`[Radar] 👷 Profissional ID ${profissional_id} está ONLINE e pronto a receber pedidos.`);
        } catch (error) {
            console.error(`Erro ao colocar profissional online:`, error);
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
                    console.error(`Erro ao colocar profissional offline:`, error);
                }

                console.log(`[Radar] 🔴 Profissional ID ${id} ficou OFFLINE.`);
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
    console.log(`🚀 Servidor e WebSockets a correr na porta ${PORT}`);
});