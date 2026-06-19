// =============================================================
// HELPI - Servidor HTTP e WebSocket
// Inicializa o servidor, configura Socket.IO e graceful shutdown.
//
// ESCALABILIDADE:
// - WebSocket autenticado com JWT
// - Rooms por tipo de usuário (cliente:id / profissional:id)
// - Graceful shutdown com timeout
// =============================================================

const app = require('./app');
const http = require('http');
const socketIo = require('socket.io');
const jwt = require('jsonwebtoken');
const logger = require('./utils/logger');
const pool = require('./config/database');

const server = http.createServer(app);

// Configuração do Socket.IO com CORS
const io = socketIo(server, {
    cors: {
        origin: process.env.CORS_ORIGIN || '*',
        methods: ['GET', 'POST'],
    },
    // Otimizações para escala
    pingTimeout: 60000,
    pingInterval: 25000,
    maxHttpBufferSize: 1e6, // 1MB max por mensagem
});

// ─── AUTENTICAÇÃO DO WEBSOCKET ──────────────────────────────
// Middleware: verifica JWT ANTES de permitir a conexão
io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;

    if (!token) {
        logger.warn(`WebSocket rejeitado: sem token (IP: ${socket.handshake.address})`);
        return next(new Error('Autenticação necessária. Envie o token JWT.'));
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.usuario = decoded; // { id, tipo, iat, exp }
        next();
    } catch (err) {
        logger.warn(`WebSocket rejeitado: token inválido (IP: ${socket.handshake.address})`);
        return next(new Error('Token inválido ou expirado.'));
    }
});

// ─── GESTÃO DE CONEXÕES ─────────────────────────────────────
io.on('connection', (socket) => {
    const { id, tipo } = socket.usuario;

    // Cada usuário entra na sua room pessoal: "cliente:uuid" ou "profissional:uuid"
    const roomPessoal = `${tipo}:${id}`;
    socket.join(roomPessoal);

    logger.info(`WebSocket conectado: ${socket.id} → room "${roomPessoal}"`);

    // Profissionais também entram numa room geral da categoria (para notificações em massa)
    socket.on('entrar_categoria', (categoria) => {
        if (typeof categoria === 'string' && categoria.trim().length > 0) {
            const roomCategoria = `categoria:${categoria.trim().toLowerCase()}`;
            socket.join(roomCategoria);
            logger.info(`Profissional ${id} entrou na room "${roomCategoria}"`);
        }
    });

    // Profissional atualiza localização em tempo real
    socket.on('atualizar_localizacao', async (dados) => {
        if (tipo !== 'profissional') return;

        const { latitude, longitude } = dados || {};
        if (typeof latitude !== 'number' || typeof longitude !== 'number') return;
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) return;

        try {
            await pool.query(
                'UPDATE profissionais SET latitude_atual = $1, longitude_atual = $2 WHERE id = $3',
                [latitude, longitude, id]
            );
        } catch (err) {
            logger.error(`Erro ao atualizar localização do profissional ${id}:`, { message: err.message });
        }
    });

    // Profissional fica online/offline
    socket.on('toggle_online', async (isOnline) => {
        if (tipo !== 'profissional') return;

        try {
            await pool.query(
                'UPDATE profissionais SET is_online = $1 WHERE id = $2',
                [!!isOnline, id]
            );
            logger.info(`Profissional ${id} agora está ${isOnline ? 'online' : 'offline'}`);
        } catch (err) {
            logger.error(`Erro ao alterar status online do profissional ${id}:`, { message: err.message });
        }
    });

    socket.on('disconnect', async () => {
        logger.info(`WebSocket desconectado: ${socket.id} (${roomPessoal})`);

        // Se for profissional, marca como offline automaticamente
        if (tipo === 'profissional') {
            try {
                await pool.query(
                    'UPDATE profissionais SET is_online = false WHERE id = $1',
                    [id]
                );
            } catch (err) {
                logger.error(`Erro ao marcar profissional ${id} como offline:`, { message: err.message });
            }
        }
    });
});

// Disponibiliza o IO para os controladores
app.set('io', io);

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
    logger.info(`🚀 Helpi API v1 rodando em http://0.0.0.0:${PORT} (Acessível na rede local)`);
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

// Captura erros não tratados para evitar crash silencioso
process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection:', { reason: reason?.message || reason });
});

process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', { message: error.message, stack: error.stack });
    process.exit(1);
});