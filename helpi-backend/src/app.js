const express = require('express');
const pool = require('./config/database');
const { errorHandler } = require('./middlewares/errorHandler');
const { validarCadastroCliente } = require('./middlewares/validators/clienteValidator');
const bcrypt = require('bcrypt'); // Adicionado pelo Victor
const swaggerUi = require('swagger-ui-express');
const swaggerSpecs = require('./config/swagger');

const app = express();

app.use(express.json());

// Uso de controladores e rotas organizados
//--------------------------------------------
//clientes
const rotasClientes = require('./routes/clientes.routes');

app.use('/api/clientes', rotasClientes); // Diz ao Express para usar o novo ficheiro

//profissionais
const rotasProfissionais = require('./routes/profissionais.routes');

app.use('/api/profissionais', rotasProfissionais);

//chamados
const rotasChamados = require('./routes/chamados.routes');

app.use('/api/chamados', rotasChamados);

//avaliações
const rotasAvaliacoes = require('./routes/avaliacoes.routes');

app.use('/api/avaliacoes', rotasAvaliacoes);

// Documentação Swagger
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpecs));

//--------------------------------------------
// -------------------------------------------------------
// STATUS DA API
// -------------------------------------------------------
app.get('/api/status', (req, res) => {
    res.json({ message: 'Motor do Helpi a funcionar perfeitamente!' });
});

// -------------------------------------------------------
// MIDDLEWARE DE ERROS — deve ser O ÚLTIMO app.use()
// -------------------------------------------------------
app.use(errorHandler);

module.exports = app;