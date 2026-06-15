const pool = require('../config/database');
const bcrypt = require('bcrypt');
const { gerarToken } = require('../utils/jwt');
const logger = require('../utils/logger');

const loginCliente = async (req, res, next) => {
    try {
        const { email, senha } = req.body;

        // Busca o cliente pelo email (normalizado para lowercase)
        const resultado = await pool.query(
            'SELECT id, nome, email, senha FROM clientes WHERE email = $1',
            [email.toLowerCase().trim()]
        );

        if (resultado.rows.length === 0) {
            logger.warn(`Tentativa de login com email inexistente: ${email}`);
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const cliente = resultado.rows[0];
        const senhaValida = await bcrypt.compare(senha, cliente.senha);

        if (!senhaValida) {
            logger.warn(`Senha incorreta para cliente: ${email}`);
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const token = gerarToken(cliente.id, 'cliente');

        logger.info(`Login de cliente bem-sucedido: ${cliente.id}`);

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

        // Busca o profissional pelo email (normalizado para lowercase)
        const resultado = await pool.query(
            'SELECT id, nome, email, senha FROM profissionais WHERE email = $1',
            [email.toLowerCase().trim()]
        );

        if (resultado.rows.length === 0) {
            logger.warn(`Tentativa de login profissional com email inexistente: ${email}`);
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        const profissional = resultado.rows[0];
        const senhaValida = await bcrypt.compare(senha, profissional.senha);

        if (!senhaValida) {
            logger.warn(`Senha incorreta para profissional: ${email}`);
            return res.status(401).json({
                erro: 'Email ou senha inválidos'
            });
        }

        // FIX: Variável corrigida (era "profisinal" — typo que causava crash)
        const token = gerarToken(profissional.id, 'profissional');

        logger.info(`Login de profissional bem-sucedido: ${profissional.id}`);

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
};

module.exports = {
    loginCliente,
    loginProfissional
};