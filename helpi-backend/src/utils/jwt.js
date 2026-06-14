const jwt = require('jsonwebtoken');

// Função para gerar o "cartão de acesso" do utilizador
const gerarToken = (usuarioId) => {
    return jwt.sign({ id: usuarioId }, process.env.JWT_SECRET, {
        expiresIn: '7d' // O utilizador mantém-se logado durante 7 dias
    });
};

module.exports = { gerarToken };