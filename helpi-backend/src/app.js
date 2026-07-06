// =============================================================
// HELPI - Aplicação Express Principal
// Configura middlewares, rotas e segurança da API.
//
// ESCALABILIDADE:
// - Compressão gzip (respostas 60-70% menores)
// - Rate-limiting global (anti-DoS)
// - CORS restrito por ambiente
// - Versionamento de API (/api/v1)
// - Health check profundo (com verificação do DB)
// =============================================================

const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const swaggerUi = require('swagger-ui-express');
const swaggerSpecs = require('./config/swagger');
const logger = require('./utils/logger');
const pool = require('./config/database');
const { errorHandler } = require('./middlewares/errorHandler');

// Importação das Rotas
const rotasClientes = require('./routes/clientes.routes');
const rotasProfissionais = require('./routes/profissionais.routes');
const rotasChamados = require('./routes/chamados.routes');
const rotasAvaliacoes = require('./routes/avaliacoes.routes');
const rotasAuth = require('./routes/auth.routes');
const rotasCategorias = require('./routes/categorias.routes');
const rotasPagamentos = require('./routes/pagamentos.routes');

const app = express();

// =============================================================
// Middlewares de Segurança
// =============================================================

// Helmet — Define headers HTTP de segurança (XSS, clickjacking, etc.)
app.use(helmet());

// CORS — Restrito por ambiente
// SEGURANÇA: origin '*' com credentials:true é inválido pela spec CORS.
// Em produção usa CORS_ORIGIN do .env; em dev usa lista local explícita.
const corsOrigins = process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(',').map(o => o.trim())
    : ['http://localhost:3000', 'http://localhost:8080', 'http://localhost:19006'];

app.use(cors({
    origin: corsOrigins,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
}));

// =============================================================
// Middlewares de Performance
// =============================================================

// Compressão gzip — reduz tamanho das respostas em 60-70%
app.use(compression({
    level: 6, // Equilíbrio entre CPU e compressão
    threshold: 1024, // Só comprimir respostas > 1KB
    filter: (req, res) => {
        if (req.headers['x-no-compression']) return false;
        return compression.filter(req, res);
    }
}));

// =============================================================
// Rate Limiting Global — Anti-DoS
// =============================================================

const globalLimiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minuto
    max: process.env.NODE_ENV === 'production' ? 100 : 1000, // 100 req/min em prod
    standardHeaders: true,
    legacyHeaders: false,
    message: {
        erro: 'Muitas requisições. Tente novamente em 1 minuto.'
    },
    skip: (req) => req.path === '/api/v1/status', // Health check sem limite
});

app.use('/api', globalLimiter);

// =============================================================
// Middlewares de Parsing e Logging
// =============================================================

// SEGURANÇA: Limite de 100kb protege contra DoS via payload gigante.
// A rota de webhook do MercadoPago é tratada com express.raw() separadamente.
app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: true, limit: '100kb' }));
app.use(morgan('combined', { stream: { write: (message) => logger.info(message.trim()) } }));

// =============================================================
// Documentação Swagger
// =============================================================

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// =============================================================
// Rotas da API v1 (Versionadas)
// =============================================================

// Novas rotas versionadas (/api/v1/...)
app.use('/api/v1', rotasAuth);
app.use('/api/v1/clientes', rotasClientes);
app.use('/api/v1/profissionais', rotasProfissionais);
app.use('/api/v1/chamados', rotasChamados);
app.use('/api/v1/avaliacoes', rotasAvaliacoes);
app.use('/api/v1/categorias', rotasCategorias);
app.use('/api/v1/pagamentos', rotasPagamentos);

// Retrocompatibilidade — rotas antigas continuam funcionando
app.use('/api', rotasAuth);
app.use('/api/clientes', rotasClientes);
app.use('/api/profissionais', rotasProfissionais);
app.use('/api/chamados', rotasChamados);
app.use('/api/avaliacoes', rotasAvaliacoes);
app.use('/api/categorias', rotasCategorias);
app.use('/api/pagamentos', rotasPagamentos);

// =============================================================
// Health Check Profundo — Verifica API + Banco de Dados
// =============================================================

app.get('/api/v1/status', async (req, res) => {
    const status = {
        status: 'online',
        mensagem: 'Motor do Helpi a funcionar perfeitamente!',
        versao: '1.0.0',
        timestamp: new Date().toISOString(),
        uptime_seconds: Math.floor(process.uptime()),
        ambiente: process.env.NODE_ENV || 'development',
    };

    // Verificação do banco de dados
    try {
        const inicio = Date.now();
        await pool.query('SELECT 1');
        status.banco_de_dados = {
            status: 'conectado',
            latencia_ms: Date.now() - inicio
        };
    } catch (err) {
        status.banco_de_dados = {
            status: 'desconectado',
            erro: process.env.NODE_ENV === 'production' ? 'Erro de conexão' : err.message
        };
        status.status = 'degradado';
    }

    const httpStatus = status.status === 'online' ? 200 : 503;
    res.status(httpStatus).json(status);
});

// Retrocompatibilidade
app.get('/api/status', async (req, res) => {
    res.redirect(301, '/api/v1/status');
});

// =============================================================
// Tratamento de Rotas Não Encontradas (404)
// =============================================================

app.use((req, res) => {
    res.status(404).json({
        erro: `Rota ${req.method} ${req.originalUrl} não encontrada.`,
        sugestao: 'Consulte a documentação em /api-docs'
    });
});

// =============================================================
// Middleware de Erros Centralizado (Sempre o último)
// =============================================================

app.use(errorHandler);

module.exports = app;