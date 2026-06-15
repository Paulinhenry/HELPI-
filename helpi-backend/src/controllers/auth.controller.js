const pool = require('../config/database');
const bcrypt = require('bcrypt');
const { gerarToken } = require('../utils/jwt');

const loginCliente = async (req, res, next) => {
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
        const senhaValida = await bcrypt.compare(senha, cliente.senha);

        if (!senhaValida) {
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const token = gerarToken(cliente.id, 'cliente');

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
};

const loginProfissional = async (req, res, next) => {
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

        const profesional = resultado.rows[0];
        const senhaValida = await bcrypt.compare(senha, profesional.senha);

        if (!senhaValida) {
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const token = gerarToken(profisinal.id, 'profissional');

        res.json({
            mensagem: 'Login realizado com sucesso',
            token,
            usuario: {
                id: profesional.id,
                nome: profesional.nome,
                email: profesional.email,
                tipo: 'profissional'
            }
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    loginCliente,
    loginProfissional
};