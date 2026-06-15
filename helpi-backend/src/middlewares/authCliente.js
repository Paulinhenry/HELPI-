const jwt = require('jsonwebtoken');

const authCliente = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader) {
            return res.status(401).json({
                erro: 'Token não fornecido'
            });
        }

        const token = authHeader.split(' ')[1];

        const decoded = jwt.verify(
            token,
            process.env.JWT_SECRET
        );

        if (decoded.tipo !== 'cliente') {
            return res.status(403).json({
                erro: 'Acesso permitido apenas para clientes'
            });
        }

        req.usuario = decoded;

        next();

    } catch (erro) {
        return res.status(401).json({
            erro: 'Token inválido ou expirado'
        });
    }
};

module.exports = authCliente;