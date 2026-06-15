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

const { validarCadastroCliente } = require('./middlewares/validators/clienteValidator');
const bcrypt = require('bcrypt'); // Adicionado pelo Victor
const { gerarToken } = require('./utils/jwt'); 
const authCliente = require('./middlewares/authCliente');
const authProfissional = require('./middlewares/authProfissional');     
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





// -------------------------------------------------------
// MIDDLEWARE DE ERROS — deve ser O ÚLTIMO app.use()
// -------------------------------------------------------
app.post('/api/login/clientes', async (req, res, next) => {
    try {
        const { email, senha } = req.body;

        const resultado = await pool.query(
            'SELECT id, nome, email, senha FROM clientes WHERE email = $1',
            [email]
        );

        if (resultado.rows.length === 0) {
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const cliente = resultado.rows[0];

        const senhaValida = await bcrypt.compare(
            senha,
            cliente.senha
        );

        if (!senhaValida) {
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const token = gerarToken(
            cliente.id,
            'cliente'
        );

        res.json({
            mensagem: 'Login realizado com sucesso',
            token,
            usuario: {
                id: cliente.id,
                nome: cliente.nome,
                email: cliente.email,
                tipo: 'cliente'
            }
        });

    } catch (erro) {
        next(erro);
    }
});

app.get('/api/teste-jwt', authCliente, (req, res) => {
    res.json({
        mensagem: 'Token válido!',
        usuario: req.usuario
    });
});

app.post('/api/login/profissionais', async (req, res, next) => {
    try {
        const { email, senha } = req.body;

        const resultado = await pool.query(
            'SELECT id, nome, email, senha FROM profissionais WHERE email = $1',
            [email]
        );

        if (resultado.rows.length === 0) {
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const profissional = resultado.rows[0];

        const senhaValida = await bcrypt.compare(
            senha,
            profissional.senha
        );

        if (!senhaValida) {
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const token = gerarToken(
            profissional.id,
            'profissional'
        );

        res.json({
            mensagem: 'Login realizado com sucesso',
            token,
            usuario: {
                id: profissional.id,
                nome: profissional.nome,
                email: profissional.email,
                tipo: 'profissional'
            }
        });

    } catch (erro) {
        next(erro);
    }
});

app.use(errorHandler);
module.exports = app;