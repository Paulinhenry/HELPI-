// =============================================================
// HELPI - Validador de Cadastro de Cliente
// Valida os campos ANTES de tocar no banco de dados.
// Usa AppError para que o errorHandler central trate a resposta.
// =============================================================

const { AppError } = require('../errorHandler');

// --- Funções auxiliares de validação ---

const validarCPF = (cpf) => {
    // Remove máscara (ex: "111.222.333-44" → "11122233344")
    const numeros = cpf.replace(/\D/g, '');

    if (numeros.length !== 11) return false;

    // Rejeita CPFs com todos os dígitos iguais (ex: 111.111.111-11)
    if (/^(\d)\1+$/.test(numeros)) return false;

    // Validação do 1º dígito verificador
    let soma = 0;
    for (let i = 0; i < 9; i++) {
        soma += parseInt(numeros[i]) * (10 - i);
    }
    let digito1 = 11 - (soma % 11);
    if (digito1 >= 10) digito1 = 0;
    if (digito1 !== parseInt(numeros[9])) return false;

    // Validação do 2º dígito verificador
    soma = 0;
    for (let i = 0; i < 10; i++) {
        soma += parseInt(numeros[i]) * (11 - i);
    }
    let digito2 = 11 - (soma % 11);
    if (digito2 >= 10) digito2 = 0;
    if (digito2 !== parseInt(numeros[10])) return false;

    return true;
};

const validarEmail = (email) => {
    // Regex simples e confiável para validação de e-mail
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
};

const validarTelefone = (telefone) => {
    // Aceita formatos: (11) 99999-9999 | 11999999999 | +5511999999999
    const numeros = telefone.replace(/\D/g, '');
    return numeros.length >= 10 && numeros.length <= 13;
};

const validarSenha = (senha) => {
    // Mínimo 8 caracteres, ao menos 1 letra e 1 número
    // (seu sócio vai criptografar — aqui só garantimos força mínima)
    return senha.length >= 8 && /[a-zA-Z]/.test(senha) && /[0-9]/.test(senha);
};

// --- O middleware em si ---

const validarCadastroCliente = (req, res, next) => {
    const { nome, cpf, email, senha, telefone } = req.body;

    const erros = [];

    // Campos obrigatórios
    if (!nome || nome.trim().length < 2) {
        erros.push('Nome é obrigatório e deve ter ao menos 2 caracteres.');
    }

    if (!cpf) {
        erros.push('CPF é obrigatório.');
    } else if (!validarCPF(cpf)) {
        erros.push('CPF inválido.');
    }

    if (!email) {
        erros.push('E-mail é obrigatório.');
    } else if (!validarEmail(email)) {
        erros.push('E-mail inválido.');
    }

    if (!senha) {
        erros.push('Senha é obrigatória.');
    } else if (!validarSenha(senha)) {
        erros.push('Senha deve ter ao menos 8 caracteres, incluindo letras e números.');
    }

    if (!telefone) {
        erros.push('Telefone é obrigatório.');
    } else if (!validarTelefone(telefone)) {
        erros.push('Telefone inválido.');
    }

    // Se houver qualquer erro, lança para o errorHandler central
    if (erros.length > 0) {
        // Retorna todos os erros de uma vez (melhor UX no app)
        return next(new AppError(erros.join(' | '), 400));
    }

    // Normaliza os dados antes de seguir para a rota
    req.body.nome = nome.trim();
    req.body.email = email.toLowerCase().trim();
    req.body.cpf = cpf.replace(/\D/g, ''); // Salva só os números no banco

    next();
};

module.exports = { validarCadastroCliente };
