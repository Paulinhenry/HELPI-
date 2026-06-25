const { criarChamado } = require('../src/controllers/chamados.controller');
const { AppError } = require('../src/middlewares/errorHandler');

// Mock dependências
jest.mock('../src/config/database', () => ({
    connect: jest.fn().mockResolvedValue({
        query: jest.fn().mockResolvedValue({ rows: [] }),
        release: jest.fn(),
    }),
}));

describe('Chamados Controller - Validação', () => {
    let req, res, next;

    beforeEach(() => {
        req = {
            usuario: { id: 1 },
            body: {},
            app: { get: jest.fn() }
        };
        res = {
            status: jest.fn().mockReturnThis(),
            json: jest.fn()
        };
        next = jest.fn();
    });

    test('Deve lançar AppError 400 se faltar algum campo obrigatório', async () => {
        req.body = { categoria_solicitada: 'Elétrica' }; // Falta descrição, lat, lng

        await criarChamado(req, res, next);

        expect(next).toHaveBeenCalledWith(expect.any(AppError));
        expect(next.mock.calls[0][0].status).toBe(400);
        expect(next.mock.calls[0][0].message).toContain('Todos os campos são obrigatórios');
    });

    test('Deve lançar AppError 400 se lat ou lng não forem números', async () => {
        req.body = {
            categoria_solicitada: 'Elétrica',
            problema_descricao: 'Teste',
            latitude_destino: 'abc', // Invalido
            longitude_destino: 10
        };

        await criarChamado(req, res, next);

        expect(next).toHaveBeenCalledWith(expect.any(AppError));
        expect(next.mock.calls[0][0].status).toBe(400);
        expect(next.mock.calls[0][0].message).toContain('Latitude e longitude devem ser números válidos');
    });
});
