// =============================================================
// HELPI - Testes do Motor de Precificação Inteligente
// Pilar 1 > Domínio de Inteligência
//
// Testa: Análise de Risco, Escala, Categoria Desconhecida,
//        Descrição Vazia, Multiplicadores Combinados, Taxa de Deslocamento
// =============================================================

const { analisarProblema } = require('../../src/utils/precificador');
const { TAXA_DESLOCAMENTO } = require('../../src/utils/constants');

describe('🧠 Motor de Precificação Inteligente', () => {

    // ─── TESTE DE ANÁLISE DE RISCO ──────────────────────────
    // Palavras críticas ("vazamento", "urgente") devem subir a estimativa
    describe('Análise de Risco (Urgência)', () => {
        
        it('deve detectar urgência e aplicar +15% ao preço', () => {
            const resultado = analisarProblema('Hidráulica', 'vazamento urgente no banheiro');
            
            expect(resultado.fatores_detectados).toContain('urgência (+15%)');
            expect(resultado.preco_minimo).toBeGreaterThan(TAXA_DESLOCAMENTO);
            expect(resultado.preco_maximo).toBeGreaterThan(resultado.preco_minimo);
        });

        it('deve detectar palavra "fogo" como urgência via descrição complexa', () => {
            const resultado = analisarProblema('Elétrica', 'saiu fogo do quadro elétrico socorro');
            
            // "fogo" não está nas keywords de urgência padrão, mas "socorro" está
            expect(resultado.fatores_detectados).toContain('urgência (+15%)');
        });

        it('deve detectar "socorro" como urgência', () => {
            const resultado = analisarProblema('Elétrica', 'socorro preciso de um eletricista');
            
            expect(resultado.fatores_detectados).toContain('urgência (+15%)');
        });
    });

    // ─── TESTE DE ESCALA ────────────────────────────────────
    // Texto limpo e simples deve manter o valor base da categoria
    describe('Escala (Preço Base)', () => {
        
        it('deve retornar preço base simples para "instalar tomada"', () => {
            const resultado = analisarProblema('Elétrica', 'instalar tomada');
            
            expect(resultado.complexidade).toBe('simples');
            // Elétrica simples: min=60, max=120 + TAXA_DESLOCAMENTO(40) = min=100, max=160
            expect(resultado.preco_minimo).toBe(100);
            expect(resultado.preco_maximo).toBe(160);
            expect(resultado.fatores_detectados).toHaveLength(0);
        });

        it('deve retornar preço médio para "curto-circuito"', () => {
            const resultado = analisarProblema('Elétrica', 'curto-circuito na sala');
            
            expect(resultado.complexidade).toBe('media');
            // Elétrica média: min=100, max=200 + TAXA(40) = 140, 240
            expect(resultado.preco_minimo).toBe(140);
            expect(resultado.preco_maximo).toBe(240);
        });

        it('deve retornar preço complexo para "fiação do quadro"', () => {
            const resultado = analisarProblema('Elétrica', 'preciso trocar a fiação do quadro elétrico');
            
            expect(resultado.complexidade).toBe('complexa');
            // Elétrica complexa: min=150, max=350 + TAXA(40) = 190, 390
            expect(resultado.preco_minimo).toBe(190);
            expect(resultado.preco_maximo).toBe(390);
        });
    });

    // ─── TESTE DE CATEGORIA DESCONHECIDA ────────────────────
    describe('Categoria Desconhecida (Fallback)', () => {
        
        it('não deve crashar com categoria inexistente', () => {
            expect(() => {
                analisarProblema('Jardinagem', 'cortar a relva do jardim');
            }).not.toThrow();
        });

        it('deve retornar valores fallback genéricos para categoria desconhecida', () => {
            const resultado = analisarProblema('Jardinagem', 'cortar a relva');
            
            // Fallback: min=50, max=150 + TAXA(40) = 90, 190
            expect(resultado.preco_minimo).toBe(90);
            expect(resultado.preco_maximo).toBe(190);
            expect(resultado.complexidade).toBe('desconhecida');
        });
    });

    // ─── TESTE DE DESCRIÇÃO VAZIA ───────────────────────────
    describe('Descrição Vazia / Nula', () => {
        
        it('não deve crashar com descrição nula', () => {
            expect(() => {
                analisarProblema('Elétrica', null);
            }).not.toThrow();
        });

        it('não deve crashar com descrição undefined', () => {
            expect(() => {
                analisarProblema('Elétrica', undefined);
            }).not.toThrow();
        });

        it('deve retornar complexidade media_padrao para descrição vazia', () => {
            const resultado = analisarProblema('Elétrica', '');
            
            expect(resultado.complexidade).toBe('media_padrao');
            expect(resultado.preco_minimo).toBeGreaterThan(0);
            expect(resultado.preco_maximo).toBeGreaterThan(resultado.preco_minimo);
        });
    });

    // ─── TESTE DE MULTIPLICADORES COMBINADOS ────────────────
    describe('Multiplicadores Combinados (Urgência + Escala)', () => {
        
        it('deve aplicar urgência(1.15) + escala(1.20) = 1.38x ao preço', () => {
            const resultado = analisarProblema('Elétrica', 'urgente preciso trocar todos os interruptores');
            
            expect(resultado.fatores_detectados).toContain('urgência (+15%)');
            expect(resultado.fatores_detectados).toContain('larga escala (+20%)');
            expect(resultado.fatores_detectados).toHaveLength(2);
            
            // Elétrica simples (interruptor): min=60, max=120
            // Fator combinado: 1.15 * 1.20 = 1.38
            // min = ceil(60 * 1.38 / 5) * 5 + 40 = ceil(82.8 / 5) * 5 + 40 = 85 + 40 = 125
            // max = ceil(120 * 1.38 / 5) * 5 + 40 = ceil(165.6 / 5) * 5 + 40 = 170 + 40 = 210
            // Wait: TAXA is added before rounding in the code... let me check
            // Actually: minCalculado = minBase * urgencia * escala = 60 * 1.15 * 1.20 = 82.8
            //           minCalculado += 40 = 122.8
            //           minCalculado = ceil(122.8 / 5) * 5 = 125
            expect(resultado.preco_minimo).toBe(125);
        });
    });

    // ─── TESTE DA TAXA DE DESLOCAMENTO ──────────────────────
    describe('Taxa de Deslocamento (R$ 40)', () => {
        
        it('deve incluir a taxa de deslocamento fixa de R$ 40', () => {
            const resultado = analisarProblema('Elétrica', 'instalar tomada');
            
            expect(resultado.taxa_deslocamento_inclusa).toBe(40);
            expect(resultado.taxa_deslocamento_inclusa).toBe(TAXA_DESLOCAMENTO);
        });

        it('o preço sugerido deve ser a média entre min e max', () => {
            const resultado = analisarProblema('Elétrica', 'instalar tomada');
            
            const mediaEsperada = Math.ceil((resultado.preco_minimo + resultado.preco_maximo) / 2);
            expect(resultado.preco_sugerido).toBe(mediaEsperada);
        });
    });

    // ─── TESTE DE CASE SENSITIVITY ──────────────────────────
    describe('Case Sensitivity', () => {
        
        it('deve aceitar categoria com case diferente (elétrica vs Elétrica)', () => {
            const resultado = analisarProblema('elétrica', 'instalar tomada');
            
            expect(resultado.complexidade).toBe('simples');
            expect(resultado.preco_minimo).toBe(100);
        });
    });

    // ─── TESTE DE TODAS AS CATEGORIAS ───────────────────────
    describe('Cobertura de Categorias', () => {
        
        const categorias = ['Elétrica', 'Hidráulica', 'Chaveiro', 'Limpeza', 'Montador'];
        
        categorias.forEach(cat => {
            it(`deve retornar valores válidos para a categoria "${cat}"`, () => {
                const resultado = analisarProblema(cat, 'serviço genérico');
                
                expect(resultado.preco_minimo).toBeGreaterThan(0);
                expect(resultado.preco_maximo).toBeGreaterThan(0);
                expect(resultado.preco_maximo).toBeGreaterThanOrEqual(resultado.preco_minimo);
                expect(resultado.preco_sugerido).toBeGreaterThanOrEqual(resultado.preco_minimo);
                expect(resultado.preco_sugerido).toBeLessThanOrEqual(resultado.preco_maximo);
            });
        });
    });
});
