const express = require('express');
const morgan = require('morgan');
const swaggerUi = require('swagger-ui-express');
const swaggerSpecs = require('./config/swagger');
const logger = require('./utils/logger');
const { errorHandler } = require('./middlewares/errorHandler');

// Importação das Rotas
const rotasClientes = require('./routes/clientes.routes');
const rotasProfissionais = require('./routes/profissionais.routes');
const rotasChamados = require('./routes/chamados.routes');
const rotasAvaliacoes = require('./routes/avaliacoes.routes');
const rotasAuth = require('./routes/auth.routes'); // Novo módulo de autenticação

// Middlewares de Autenticação para uso futuro direto nas rotas protegidas
const authCliente = require('./middlewares/authCliente');
const authProfissional = require('./middlewares/authProfissional');     

const app = express();

// Middlewares Globais
app.use(express.json());
app.use(morgan('combined', { stream: { write: (message) => logger.info(message.trim()) } }));

// Documentação
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// Ativação das Rotas
app.use('/api', rotasAuth); // Define a base /api para as rotas de login (/api/login/...)
app.use('/api/clientes', rotasClientes);
app.use('/api/profissionais', rotasProfissionais);
app.use('/api/chamados', rotasChamados);
app.use('/api/avaliacoes', rotasAvaliacoes);

// Status da API
app.get('/api/status', (req, res) => {
    res.json({ message: 'Motor do Helpi a funcionar perfeitamente!' });
});

// Rota de teste para validação do JWT
app.get('/api/teste-jwt', authCliente, (req, res) => {
    res.json({
        mensagem: 'Token válido!',
        usuario: req.usuario
    });
});

// Middleware de Erros Centralizado (Sempre o último)
app.use(errorHandler);

module.exports = app;