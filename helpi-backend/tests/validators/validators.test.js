// =============================================================
// HELPI - Testes dos Validators (Unitários Puros — sem DB)
// Testa as funções de validação isoladamente.
// =============================================================

const { AppError } = require('../../src/middlewares/errorHandler');

// ─── HELPERS ────────────────────────────────────────────────
const mockReq = (body = {}) => ({ body, params: {} });
const mockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

// ═══════════════════════════════════════════════════════════════
// 1. VALIDATOR DE CADASTRO DE CLIENTE
// ═══════════════════════════════════════════════════════════════
describe('validarCadastroCliente', () => {
    const { validarCadastroCliente } = require('../../src/middlewares/validators/clienteValidator');

    const dadosValidos = {
        nome: 'João Silva',
        cpf: '529.982.247-25', // CPF válido (com máscara)
        email: 'joao@email.com',
        senha: 'minhasenha123',
        telefone: '11999999999',
    };

    test('Deve aceitar dados válidos e normalizar campos', (done) => {
        const req = mockReq({ ...dadosValidos });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.email).toBe('joao@email.com');
            expect(req.body.cpf).toBe('52998224725'); // Sem máscara
            expect(req.body.nome).toBe('João Silva');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar nome com menos de 2 caracteres', (done) => {
        const req = mockReq({ ...dadosValidos, nome: 'A' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.status).toBe(400);
            expect(err.message).toContain('Nome');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar sem nome', (done) => {
        const req = mockReq({ ...dadosValidos, nome: '' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    // ─── CPF ───────────────────────────────────────────────
    test('Deve rejeitar CPF com todos os dígitos iguais (111.111.111-11)', (done) => {
        const req = mockReq({ ...dadosValidos, cpf: '111.111.111-11' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('CPF');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar CPF com checksum errado', (done) => {
        const req = mockReq({ ...dadosValidos, cpf: '123.456.789-00' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('CPF');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar CPF com menos de 11 dígitos', (done) => {
        const req = mockReq({ ...dadosValidos, cpf: '1234' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve aceitar CPF válido sem máscara', (done) => {
        const req = mockReq({ ...dadosValidos, cpf: '52998224725' });
        const next = (err) => {
            expect(err).toBeUndefined();
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    // ─── EMAIL ─────────────────────────────────────────────
    test('Deve rejeitar email sem @', (done) => {
        const req = mockReq({ ...dadosValidos, email: 'joaoemail.com' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('E-mail');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar email sem domínio', (done) => {
        const req = mockReq({ ...dadosValidos, email: 'joao@' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve normalizar email para lowercase', (done) => {
        const req = mockReq({ ...dadosValidos, email: 'JOAO@EMAIL.COM' });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.email).toBe('joao@email.com');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    // ─── SENHA ─────────────────────────────────────────────
    test('Deve rejeitar senha com menos de 8 caracteres', (done) => {
        const req = mockReq({ ...dadosValidos, senha: 'abc1' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Senha');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar senha sem números', (done) => {
        const req = mockReq({ ...dadosValidos, senha: 'abcdefghij' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Senha');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve rejeitar senha sem letras', (done) => {
        const req = mockReq({ ...dadosValidos, senha: '123456789' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Senha');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    // ─── TELEFONE ──────────────────────────────────────────
    test('Deve rejeitar telefone com menos de 10 dígitos', (done) => {
        const req = mockReq({ ...dadosValidos, telefone: '12345' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Telefone');
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve aceitar telefone com máscara (11) 99999-9999', (done) => {
        const req = mockReq({ ...dadosValidos, telefone: '(11) 99999-9999' });
        const next = (err) => {
            expect(err).toBeUndefined();
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    test('Deve aceitar telefone internacional +5511999999999', (done) => {
        const req = mockReq({ ...dadosValidos, telefone: '+5511999999999' });
        const next = (err) => {
            expect(err).toBeUndefined();
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });

    // ─── MÚLTIPLOS ERROS ───────────────────────────────────
    test('Deve retornar todos os erros de uma vez (UX)', (done) => {
        const req = mockReq({
            nome: '',
            cpf: '',
            email: '',
            senha: '',
            telefone: '',
        });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.status).toBe(400);
            // Deve conter múltiplos erros separados por |
            const partes = err.message.split('|');
            expect(partes.length).toBeGreaterThanOrEqual(4);
            done();
        };
        validarCadastroCliente(req, mockRes(), next);
    });
});

// ═══════════════════════════════════════════════════════════════
// 2. VALIDATOR DE CADASTRO DE PROFISSIONAL
// ═══════════════════════════════════════════════════════════════
describe('validarCadastroProfissional', () => {
    const { validarCadastroProfissional, CATEGORIAS_VALIDAS } = require('../../src/middlewares/validators/profissionalValidator');

    const dadosValidos = {
        nome: 'Carlos Eletricista',
        cpf_cnpj: '12345678901', // 11 dígitos (CPF)
        email: 'carlos@email.com',
        senha: 'minhasenha123',
        telefone: '11988887777',
        categoria: 'Eletricista',
        biografia: 'Profissional com 10 anos de experiência.',
    };

    test('Deve aceitar dados válidos e normalizar', (done) => {
        const req = mockReq({ ...dadosValidos });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.email).toBe('carlos@email.com');
            expect(req.body.cpf_cnpj).toBe('12345678901');
            done();
        };
        validarCadastroProfissional(req, mockRes(), next);
    });

    test('Deve rejeitar categoria inválida', (done) => {
        const req = mockReq({ ...dadosValidos, categoria: 'Astronauta' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Categoria');
            done();
        };
        validarCadastroProfissional(req, mockRes(), next);
    });

    test('Deve aceitar todas as categorias válidas', () => {
        expect(CATEGORIAS_VALIDAS).toContain('Eletricista');
        expect(CATEGORIAS_VALIDAS).toContain('Encanador');
        expect(CATEGORIAS_VALIDAS).toContain('Chaveiro');
        expect(CATEGORIAS_VALIDAS).toContain('Limpeza');
        expect(CATEGORIAS_VALIDAS).toContain('Montador');
    });

    test('Deve aceitar CNPJ (14 dígitos)', (done) => {
        const req = mockReq({ ...dadosValidos, cpf_cnpj: '12345678000199' });
        const next = (err) => {
            expect(err).toBeUndefined();
            done();
        };
        validarCadastroProfissional(req, mockRes(), next);
    });

    test('Deve rejeitar documento com tamanho errado (10 dígitos)', (done) => {
        const req = mockReq({ ...dadosValidos, cpf_cnpj: '1234567890' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('CPF/CNPJ');
            done();
        };
        validarCadastroProfissional(req, mockRes(), next);
    });

    test('Deve aceitar CNPJ com máscara', (done) => {
        const req = mockReq({ ...dadosValidos, cpf_cnpj: '12.345.678/0001-99' });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.cpf_cnpj).toBe('12345678000199'); // Sem máscara
            done();
        };
        validarCadastroProfissional(req, mockRes(), next);
    });
});

// ═══════════════════════════════════════════════════════════════
// 3. VALIDATOR DE LOGIN
// ═══════════════════════════════════════════════════════════════
describe('validarLogin', () => {
    const { validarLogin } = require('../../src/middlewares/validators/loginValidator');

    test('Deve aceitar email e senha válidos', (done) => {
        const req = mockReq({ email: 'joao@email.com', senha: 'senha123' });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.email).toBe('joao@email.com');
            done();
        };
        validarLogin(req, mockRes(), next);
    });

    test('Deve rejeitar sem email', (done) => {
        const req = mockReq({ email: '', senha: 'senha123' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('E-mail');
            done();
        };
        validarLogin(req, mockRes(), next);
    });

    test('Deve rejeitar email malformado', (done) => {
        const req = mockReq({ email: 'nao-eh-email', senha: 'senha123' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('E-mail');
            done();
        };
        validarLogin(req, mockRes(), next);
    });

    test('Deve rejeitar sem senha', (done) => {
        const req = mockReq({ email: 'joao@email.com', senha: '' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Senha');
            done();
        };
        validarLogin(req, mockRes(), next);
    });

    test('Deve normalizar email para lowercase', (done) => {
        const req = mockReq({ email: 'JOAO@EMAIL.COM', senha: 'senha123' });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.email).toBe('joao@email.com');
            done();
        };
        validarLogin(req, mockRes(), next);
    });
});

// ═══════════════════════════════════════════════════════════════
// 4. VALIDATOR DE CRIAÇÃO DE CHAMADO
// ═══════════════════════════════════════════════════════════════
describe('validarCriacaoChamado', () => {
    const { validarCriacaoChamado } = require('../../src/middlewares/validators/chamadoValidator');

    const dadosValidos = {
        categoria_solicitada: 'Eletricista',
        problema_descricao: 'Curto-circuito na sala de estar, urgente!',
        latitude_destino: -23.557434,
        longitude_destino: -46.662153,
    };

    test('Deve aceitar dados válidos', (done) => {
        const req = mockReq({ ...dadosValidos });
        const next = (err) => {
            expect(err).toBeUndefined();
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });

    test('Deve rejeitar latitude fora de range (> 90)', (done) => {
        const req = mockReq({ ...dadosValidos, latitude_destino: 91 });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Latitude');
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });

    test('Deve rejeitar latitude fora de range (< -90)', (done) => {
        const req = mockReq({ ...dadosValidos, latitude_destino: -91 });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Latitude');
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });

    test('Deve rejeitar longitude fora de range (> 180)', (done) => {
        const req = mockReq({ ...dadosValidos, longitude_destino: 200 });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('Longitude');
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });

    test('Deve rejeitar descrição com menos de 10 caracteres', (done) => {
        const req = mockReq({ ...dadosValidos, problema_descricao: 'curto' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('descrição');
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });

    test('Deve rejeitar sem categoria', (done) => {
        const req = mockReq({ ...dadosValidos, categoria_solicitada: '' });
        const next = (err) => {
            expect(err).toBeInstanceOf(AppError);
            expect(err.message).toContain('categoria');
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });

    test('Deve normalizar campos (trim)', (done) => {
        const req = mockReq({
            ...dadosValidos,
            categoria_solicitada: '  Eletricista  ',
            problema_descricao: '  Curto-circuito na sala de estar!  '
        });
        const next = (err) => {
            expect(err).toBeUndefined();
            expect(req.body.categoria_solicitada).toBe('Eletricista');
            expect(req.body.problema_descricao).toBe('Curto-circuito na sala de estar!');
            done();
        };
        validarCriacaoChamado(req, mockRes(), next);
    });
});

// ═══════════════════════════════════════════════════════════════
// 5. VALIDATOR DE UUID
// ═══════════════════════════════════════════════════════════════
describe('validarUUID', () => {
    const { validarUUID } = require('../../src/middlewares/validators/uuidValidator');

    test('Deve aceitar UUID v4 válido', (done) => {
        const req = { params: { id: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d' } };
        const next = (err) => {
            expect(err).toBeUndefined();
            done();
        };
        validarUUID(req, mockRes(), next);
    });

    test('Deve rejeitar string aleatória', () => {
        const req = { params: { id: 'not-a-uuid' } };
        const res = mockRes();
        const next = jest.fn();
        validarUUID(req, res, next);
        expect(res.status).toHaveBeenCalledWith(400);
        expect(res.json).toHaveBeenCalledWith(
            expect.objectContaining({ erro: expect.stringContaining('UUID') })
        );
        expect(next).not.toHaveBeenCalled();
    });

    test('Deve rejeitar ID numérico', () => {
        const req = { params: { id: '12345' } };
        const res = mockRes();
        const next = jest.fn();
        validarUUID(req, res, next);
        expect(res.status).toHaveBeenCalledWith(400);
    });

    test('Deve rejeitar UUID vazio', () => {
        const req = { params: { id: '' } };
        const res = mockRes();
        const next = jest.fn();
        validarUUID(req, res, next);
        expect(res.status).toHaveBeenCalledWith(400);
    });

    test('Deve rejeitar SQL injection como ID', () => {
        const req = { params: { id: "'; DROP TABLE users; --" } };
        const res = mockRes();
        const next = jest.fn();
        validarUUID(req, res, next);
        expect(res.status).toHaveBeenCalledWith(400);
        expect(next).not.toHaveBeenCalled();
    });
});
