// =============================================================
// HELPI - Controlador de Autenticação
// Login de clientes e profissionais + Refresh Token
//
// ESCALABILIDADE:
// - Retorna access_token (15min) + refresh_token (30d)
// - Endpoint /refresh para renovar sem re-login
// =============================================================

const pool = require('../config/database');
const bcrypt = require('bcrypt');
const { gerarTokens, verificarRefreshToken, gerarAccessToken } = require('../utils/jwt');
const logger = require('../utils/logger');

// ─── LOGIN CLIENTE ──────────────────────────────────────────
const loginCliente = async (req, res, next) => {
    try {
        const { email, senha } = req.body;

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

        // Gera o par access + refresh
        const tokens = gerarTokens(cliente.id, 'cliente');

        logger.info(`Login de cliente bem-sucedido: ${cliente.id}`);

        res.json({
            mensagem: 'Login realizado com sucesso',
            access_token: tokens.accessToken,
            refresh_token: tokens.refreshToken,
            // Retrocompatibilidade: mantém campo "token" para apps antigos
            token: tokens.accessToken,
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

// ─── LOGIN PROFISSIONAL ─────────────────────────────────────
const loginProfissional = async (req, res, next) => {
    try {
        const { email, senha } = req.body;

        const resultado = await pool.query(
            'SELECT id, nome, email, senha, status FROM profissionais WHERE email = $1',
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

        // Verifica se o profissional está aprovado
        if (profissional.status !== 'aprovado') {
            return res.status(403).json({
                erro: 'A sua conta ainda não foi aprovada. Aguarde a validação.',
                status_conta: profissional.status
            });
        }

        const tokens = gerarTokens(profissional.id, 'profissional');

        logger.info(`Login de profissional bem-sucedido: ${profissional.id}`);

        res.json({
            mensagem: 'Login realizado com sucesso',
            access_token: tokens.accessToken,
            refresh_token: tokens.refreshToken,
            token: tokens.accessToken,
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

// ─── REFRESH TOKEN ──────────────────────────────────────────
// O cliente envia o refresh_token e recebe um novo access_token
// sem precisar fazer login novamente
const refreshToken = async (req, res, next) => {
    try {
        const { refresh_token } = req.body;

        if (!refresh_token) {
            return res.status(400).json({
                erro: 'Refresh token é obrigatório.'
            });
        }

        // Verifica se o refresh token é válido
        let decoded;
        try {
            decoded = verificarRefreshToken(refresh_token);
        } catch (err) {
            if (err.name === 'TokenExpiredError') {
                return res.status(401).json({
                    erro: 'Refresh token expirado. Faça login novamente.'
                });
            }
            return res.status(401).json({
                erro: 'Refresh token inválido.'
            });
        }

        // Verifica se o usuário ainda existe no banco
        const tabela = decoded.tipo === 'cliente' ? 'clientes' : 'profissionais';
        const resultado = await pool.query(`SELECT id FROM ${tabela} WHERE id = $1`, [decoded.id]);

        if (resultado.rows.length === 0) {
            return res.status(401).json({
                erro: 'Usuário não encontrado. Faça login novamente.'
            });
        }

        // Gera novo access token (o refresh continua válido)
        const novoAccessToken = gerarAccessToken(decoded.id, decoded.tipo);

        logger.info(`Token renovado para ${decoded.tipo}: ${decoded.id}`);

        res.json({
            mensagem: 'Token renovado com sucesso',
            access_token: novoAccessToken,
            token: novoAccessToken // Retrocompatibilidade
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = {
    loginCliente,
    loginProfissional,
    refreshToken
};