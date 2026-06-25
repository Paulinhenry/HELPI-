const { CATEGORIAS_FRONTEND } = require('../utils/constants');

const listarCategorias = (req, res) => {
    try {
        res.status(200).json({
            mensagem: 'Categorias recuperadas com sucesso',
            categorias: CATEGORIAS_FRONTEND
        });
    } catch (erro) {
        res.status(500).json({ erro: 'Erro ao recuperar categorias' });
    }
};

module.exports = { listarCategorias };
