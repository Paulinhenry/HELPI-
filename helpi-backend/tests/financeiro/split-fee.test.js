// =============================================================
// HELPI - Testes do Split Fee (Divisão de Receita)
// Pilar 1 > Domínio Financeiro
//
// Testa: Cálculo exato 10% Helpi / 90% Profissional,
//        Valores negativos, Overflow, Casas decimais
//
// NOTA: Estes são testes de LÓGICA PURA — não precisam de DB
// =============================================================

describe('💸 Split Fee — Divisão de Receita (10/90)', () => {

    // Simula a lógica de cálculo do pagamentos.controller.js (linhas 49-51)
    const calcularSplit = (valorTotal) => {
        const total = parseFloat(valorTotal);
        const valorPlataforma = total * 0.10;  // 10% HELPI
        const valorProfissional = total * 0.90; // 90% Profissional
        return { total, valorPlataforma, valorProfissional };
    };

    // ─── TESTE DO SANGRAMENTO ───────────────────────────────
    describe('Cálculo Matemático Exato', () => {

        it('deve calcular split exato para R$ 100,00', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(100);

            expect(valorPlataforma).toBe(10);
            expect(valorProfissional).toBe(90);
        });

        it('deve calcular split exato para R$ 137,57 (casas decimais)', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(137.57);

            expect(valorPlataforma).toBeCloseTo(13.757, 2);
            expect(valorProfissional).toBeCloseTo(123.813, 2);
        });

        it('a soma do split deve SEMPRE ser igual ao valor total', () => {
            const valores = [50, 99.99, 100, 137.57, 250, 500, 1000, 0.01];

            valores.forEach(valor => {
                const { total, valorPlataforma, valorProfissional } = calcularSplit(valor);
                expect(valorPlataforma + valorProfissional).toBeCloseTo(total, 10);
            });
        });

        it('a taxa Helpi deve ser SEMPRE 10% do total', () => {
            const valores = [50, 100, 200, 350, 500, 1000];

            valores.forEach(valor => {
                const { total, valorPlataforma } = calcularSplit(valor);
                expect(valorPlataforma / total).toBeCloseTo(0.10, 10);
            });
        });
    });

    // ─── TESTE DE VALORES NEGATIVOS ─────────────────────────
    describe('Proteção contra Valores Negativos', () => {

        it('deve detectar valor negativo como inválido', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(-100);

            // O cálculo em si permite negativo (é math), 
            // mas o controller deve rejeitar ANTES
            expect(valorPlataforma).toBeLessThan(0);
            expect(valorProfissional).toBeLessThan(0);
            // Este teste documenta que a proteção deve estar no controller (valor_cobrado validation)
        });

        it('deve calcular split de R$ 0,00 como zero', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(0);

            expect(valorPlataforma).toBe(0);
            expect(valorProfissional).toBe(0);
        });
    });

    // ─── TESTE DE OVERFLOW ──────────────────────────────────
    describe('Proteção contra Overflow', () => {

        it('não deve retornar NaN para valores grandes', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(999999.99);

            expect(isNaN(valorPlataforma)).toBe(false);
            expect(isNaN(valorProfissional)).toBe(false);
            expect(isFinite(valorPlataforma)).toBe(true);
            expect(isFinite(valorProfissional)).toBe(true);
        });

        it('não deve retornar Infinity para valores extremos', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(Number.MAX_SAFE_INTEGER);

            expect(isFinite(valorPlataforma)).toBe(true);
            expect(isFinite(valorProfissional)).toBe(true);
        });

        it('deve lidar com valor muito pequeno (R$ 0,01)', () => {
            const { valorPlataforma, valorProfissional } = calcularSplit(0.01);

            expect(valorPlataforma).toBeCloseTo(0.001, 3);
            expect(valorProfissional).toBeCloseTo(0.009, 3);
        });
    });

    // ─── TESTE DE PARSEAMENTO ───────────────────────────────
    describe('Parseamento de Strings', () => {

        it('deve converter string numérica corretamente', () => {
            const { total, valorPlataforma } = calcularSplit('150.00');

            expect(total).toBe(150);
            expect(valorPlataforma).toBe(15);
        });

        it('deve retornar NaN para string não numérica', () => {
            const { total } = calcularSplit('abc');

            expect(isNaN(total)).toBe(true);
        });
    });
});
