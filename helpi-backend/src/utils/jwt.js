const jwt = require('jsonwebtoken');

// Função para gerar o "cartão de acesso" do utilizador
const gerarToken = (usuarioId, tipo) => {
    return jwt.sign(
        {
            id: usuarioId,
            tipo: tipo
        },
        process.env.JWT_SECRET,
        {
            expiresIn: '7d'
        }
    );
};

module.exports = { gerarToken };        