// =============================================================
// HELPI - Testes do Error Handler Centralizado (Unitários Puros)
// Testa o middleware de erros com todos os cenários possíveis.
// =============================================================

const { errorHandler, AppError } = require('../src/middlewares/errorHandler');

// ─── HELPERS ────────────────────────────────────────────────
const mockReq = () => ({
    originalUrl: '/api/v1/test',
    method: 'POST',
});

const mockRes = () => {
    const res = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
};

const mockNext = jest.fn();

describe('Error Handler Centralizado', () => {
    afterEach(() => jest.clearAllMocks());

    // ═══ AppError (erros operacionais) ══════════════════════
    describe('AppError (erros operacionais)', () => {
        test('Deve retornar o status e mensagem do AppError', () => {
            const err = new AppError('Campo obrigatório não enviado.', 400);
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith({ erro: 'Campo obrigatório não enviado.' });
        });

        test('Deve retornar 403 para AppError com status personalizado', () => {
            const err = new AppError('Sem permissão.', 403);
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(403);
        });

        test('AppError deve ter isOperational = true', () => {
            const err = new AppError('teste');
            expect(err.isOperational).toBe(true);
        });

        test('AppError deve ter status default 400', () => {
            const err = new AppError('teste');
            expect(err.status).toBe(400);
        });
    });

    // ═══ Erros do PostgreSQL ════════════════════════════════
    describe('Erros do PostgreSQL', () => {
        test('23505 (unique_violation) deve retornar 409', () => {
            const err = { code: '23505', message: 'duplicate key' };
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(409);
            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    erro: expect.stringContaining('e-mail ou CPF já está cadastrado'),
                })
            );
        });

        test('23502 (not_null_violation) deve retornar 400', () => {
            const err = { code: '23502', message: 'null value' };
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    erro: expect.stringContaining('campo obrigatório'),
                })
            );
        });

        test('23503 (foreign_key_violation) deve retornar 400', () => {
            const err = { code: '23503', message: 'foreign key' };
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    erro: expect.stringContaining('Referência inválida'),
                })
            );
        });

        test('22001 (string_data_right_truncation) deve retornar 400', () => {
            const err = { code: '22001', message: 'value too long' };
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    erro: expect.stringContaining('longo demais'),
                })
            );
        });

        test('42P01 (undefined_table) deve retornar 500', () => {
            const err = { code: '42P01', message: 'relation does not exist' };
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(500);
        });
    });

    // ═══ JSON Malformado ════════════════════════════════════
    describe('JSON Malformado', () => {
        test('entity.parse.failed deve retornar 400 com mensagem amigável', () => {
            const err = { type: 'entity.parse.failed', message: 'Unexpected token' };
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(400);
            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    erro: expect.stringContaining('JSON válido'),
                })
            );
        });
    });

    // ═══ Erros Desconhecidos (Bugs) ═════════════════════════
    describe('Erros Desconhecidos', () => {
        test('Em development, deve incluir detalhes do erro', () => {
            const originalEnv = process.env.NODE_ENV;
            process.env.NODE_ENV = 'development';

            const err = new Error('Stack trace secreto');
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(500);
            expect(res.json).toHaveBeenCalledWith(
                expect.objectContaining({
                    erro: 'Erro interno do servidor.',
                    detalhes: 'Stack trace secreto',
                })
            );

            process.env.NODE_ENV = originalEnv;
        });

        test('Em production, NÃO deve expor detalhes internos', () => {
            const originalEnv = process.env.NODE_ENV;
            process.env.NODE_ENV = 'production';

            const err = new Error('Stack trace secreto');
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(500);
            const chamada = res.json.mock.calls[0][0];
            expect(chamada.erro).toBe('Erro interno do servidor.');
            expect(chamada.detalhes).toBeUndefined();

            process.env.NODE_ENV = originalEnv;
        });

        test('Deve retornar 500 para erro genérico sem código PG', () => {
            const err = new Error('Algo deu muito errado');
            const res = mockRes();

            errorHandler(err, mockReq(), res, mockNext);

            expect(res.status).toHaveBeenCalledWith(500);
        });
    });
});
