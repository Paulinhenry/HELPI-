// =============================================================
// HELPI - Validador de Cadastro de Profissional
// Valida os campos ANTES de tocar no banco de dados.
// =============================================================

const { AppError } = require('../errorHandler');

// Categorias aceitas pelo sistema (expandir conforme necessário)
const CATEGORIAS_VALIDAS = [
    'Eletricista',
    'Encanador',
    'Chaveiro',
    'Limpeza',
    'Montador',
    'Pintor',
    'Pedreiro',
    'Marceneiro',
    'Serralheiro',
    'Técnico de Ar Condicionado',
    'Técnico de Informática',
    'Jardineiro',
    'Desentupidor'
];

const validarEmail = (email) => {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};

const validarTelefone = (telefone) => {
    const numeros = telefone.replace(/\D/g, '');
    return numeros.length >= 10 && numeros.length <= 13;
};

const validarSenha = (senha) => {
    return senha.length >= 8 && /[a-zA-Z]/.test(senha) && /[0-9]/.test(senha);
};

const validarCPFouCNPJ = (documento) => {
    const numeros = documento.replace(/\D/g, '');
    // CPF tem 11 dígitos, CNPJ tem 14
    return numeros.length === 11 || numeros.length === 14;
};

const validarCadastroProfissional = (req, res, next) => {
    const { nome, cpf_cnpj, email, senha, telefone, categoria, biografia } = req.body;
    const erros = [];

    // Nome
    if (!nome || nome.trim().length < 2) {
        erros.push('Nome é obrigatório e deve ter ao menos 2 caracteres.');
    }

    // Documento (CPF ou CNPJ)
    if (!cpf_cnpj) {
        erros.push('CPF ou CNPJ é obrigatório.');
    } else if (!validarCPFouCNPJ(cpf_cnpj)) {
        erros.push('CPF/CNPJ inválido. Deve conter 11 (CPF) ou 14 (CNPJ) dígitos.');
    }

    // Email
    if (!email) {
        erros.push('E-mail é obrigatório.');
    } else if (!validarEmail(email)) {
        erros.push('E-mail inválido.');
    }

    // Senha
    if (!senha) {
        erros.push('Senha é obrigatória.');
    } else if (!validarSenha(senha)) {
        erros.push('Senha deve ter ao menos 8 caracteres, incluindo letras e números.');
    }

    // Telefone
    if (!telefone) {
        erros.push('Telefone é obrigatório.');
    } else if (!validarTelefone(telefone)) {
        erros.push('Telefone inválido.');
    }

    // Categoria
    if (!categoria) {
        erros.push('Categoria é obrigatória.');
    } else if (!CATEGORIAS_VALIDAS.includes(categoria)) {
        erros.push(`Categoria inválida. Categorias aceitas: ${CATEGORIAS_VALIDAS.join(', ')}`);
    }

    if (erros.length > 0) {
        return next(new AppError(erros.join(' | '), 400));
    }

    // Normaliza dados antes de seguir
    req.body.nome = nome.trim();
    req.body.email = email.toLowerCase().trim();
    req.body.cpf_cnpj = cpf_cnpj.replace(/\D/g, '');

    next();
};

module.exports = { validarCadastroProfissional, CATEGORIAS_VALIDAS };
