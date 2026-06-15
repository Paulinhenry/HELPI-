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

const app = express();

// Middlewares Globais
app.use(express.json());
app.use(morgan('combined', { stream: { write: (message) => logger.info(message.trim()) } }));

// Documentação
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

// Rotas
app.use('/api/clientes', rotasClientes);
app.use('/api/profissionais', rotasProfissionais);
app.use('/api/chamados', rotasChamados);
app.use('/api/avaliacoes', rotasAvaliacoes);

//status API
app.get('/api/status', (req, res) => {
    res.json({ message: 'Motor do Helpi a funcionar perfeitamente!' });
});

// Middleware de Erros (sempre no final)
app.use(errorHandler);

module.exports = app;