// =============================================================
// HELPI - Servidor HTTP e WebSocket
// Inicializa o servidor, configura Socket.IO e graceful shutdown.
// =============================================================

const app = require('./app');
const http = require('http');
const socketIo = require('socket.io');
const logger = require('./utils/logger');
const pool = require('./config/database');

const server = http.createServer(app);

// Configuração do Socket.IO com CORS
const io = socketIo(server, {
    cors: {
        origin: process.env.CORS_ORIGIN || '*',
        methods: ['GET', 'POST'],
    },
});

// Disponibiliza o IO para os controladores
app.set('io', io);

// Log de conexões WebSocket
io.on('connection', (socket) => {
    logger.info(`WebSocket conectado: ${socket.id}`);

    socket.on('disconnect', () => {
        logger.info(`WebSocket desconectado: ${socket.id}`);
    });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
    logger.info(`🚀 Helpi API rodando em http://0.0.0.0:${PORT} (Acessível na rede local)`);
    logger.info(`📄 Documentação disponível em http://localhost:${PORT}/api-docs`);
});

// =============================================================
// Graceful Shutdown — Fecha conexões corretamente ao parar
// =============================================================

const gracefulShutdown = async (signal) => {
    logger.info(`${signal} recebido. Encerrando o servidor graciosamente...`);

    server.close(async () => {
        logger.info('Servidor HTTP encerrado.');

        try {
            await pool.end();
            logger.info('Pool de conexões com o banco encerrada.');
        } catch (err) {
            logger.error('Erro ao encerrar pool do banco:', { message: err.message });
        }

        io.close(() => {
            logger.info('Conexões WebSocket encerradas.');
        });

        process.exit(0);
    });

    // Force shutdown após 10 segundos se o graceful falhar
    setTimeout(() => {
        logger.error('Graceful shutdown falhou. Forçando encerramento.');
        process.exit(1);
    }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));