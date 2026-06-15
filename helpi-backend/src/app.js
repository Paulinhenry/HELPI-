// =============================================================
// HELPI - Aplicação Express Principal
// Configura middlewares, rotas e segurança da API.
// =============================================================

const express = require('express');
const morgan = require('morgan');
const cors = require('cors');
const helmet = require('helmet');
const swaggerUi = require('swagger-ui-express');
const swaggerSpecs = require('./config/swagger');
const logger = require('./utils/logger');
const { errorHandler } = require('./middlewares/errorHandler');

// Importação das Rotas
const rotasClientes = require('./routes/clientes.routes');
const rotasProfissionais = require('./routes/profissionais.routes');
const rotasChamados = require('./routes/chamados.routes');
const rotasAvaliacoes = require('./routes/avaliacoes.routes');
const rotasAuth = require('./routes/auth.routes');

const app = express();

// =============================================================
// Middlewares de Segurança
// =============================================================

// Helmet — Define headers HTTP de segurança (XSS, clickjacking, etc.)
app.use(helmet());

// CORS — Controla quais origens podem acessar a API
app.use(cors({
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
}));

// =============================================================
// Middlewares de Parsing e Logging
// =============================================================

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined', { stream: { write: (message) => logger.info(message.trim()) } }));

// =============================================================
// Documentação Swagger
// =============================================================

app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// =============================================================
// Rotas da API
// =============================================================

app.use('/api', rotasAuth);
app.use('/api/clientes', rotasClientes);
app.use('/api/profissionais', rotasProfissionais);
app.use('/api/chamados', rotasChamados);
app.use('/api/avaliacoes', rotasAvaliacoes);

// Health Check — Status da API
app.get('/api/status', (req, res) => {
    res.json({
        status: 'online',
        mensagem: 'Motor do Helpi a funcionar perfeitamente!',
        timestamp: new Date().toISOString()
    });
});

// =============================================================
// Tratamento de Rotas Não Encontradas (404)
// =============================================================

app.use((req, res) => {
    res.status(404).json({
        erro: `Rota ${req.method} ${req.originalUrl} não encontrada.`
    });
});

// =============================================================
// Middleware de Erros Centralizado (Sempre o último)
// =============================================================

app.use(errorHandler);

module.exports = app;