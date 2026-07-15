const jwt = require('jsonwebtoken');

const authGeral = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                erro: 'Token não fornecido. Envie no formato: Bearer <token>'
            });
        }

        const token = authHeader.split(' ')[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        
        req.usuario = decoded;
        next();

    } catch (erro) {
        if (erro.name === 'TokenExpiredError') {
            return res.status(401).json({
                erro: 'Token expirado. Faça login novamente.'
            });
        }
        return res.status(401).json({
            erro: 'Token inválido'
        });
    }
};

module.exports = authGeral;
