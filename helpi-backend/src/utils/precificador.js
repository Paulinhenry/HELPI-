// =============================================================
// HELPI - Motor de Precificação Inteligente
// Analisa a descrição do problema para estimar valores (base + taxa)
// =============================================================

const { TAXA_DESLOCAMENTO } = require('./constants');

const DICIONARIO_CATEGORIAS = {
    'Elétrica': {
        simples: { min: 60, max: 120, keywords: ['tomada', 'interruptor', 'lâmpada', 'lampada', 'led'] },
        media: { min: 100, max: 200, keywords: ['curto', 'curto-circuito', 'disjuntor', 'chuveiro', 'resistência'] },
        complexa: { min: 150, max: 350, keywords: ['fiação', 'quadro', 'painel', 'padrão'] }
    },
    'Hidráulica': {
        simples: { min: 60, max: 130, keywords: ['torneira', 'sifão', 'ralo', 'chuveirinho'] },
        media: { min: 100, max: 250, keywords: ['vazamento', 'cano', 'entupido', 'entupimento', 'pia'] },
        complexa: { min: 150, max: 400, keywords: ['esgoto', 'caixa', 'bomba'] }
    },
    'Chaveiro': {
        simples: { min: 60, max: 120, keywords: ['trancada', 'esqueci', 'chave', 'abrir'] },
        media: { min: 80, max: 150, keywords: ['troca', 'fechadura', 'miolo', 'tambor', 'cópia'] },
        complexa: { min: 150, max: 350, keywords: ['cofre', 'blindada', 'eletrônica'] }
    },
    'Limpeza': {
        simples: { min: 80, max: 150, keywords: ['apartamento', 'quarto', 'pequena', 'estúdio'] },
        media: { min: 120, max: 250, keywords: ['casa', 'faxina', 'completa', 'pesada'] },
        complexa: { min: 200, max: 500, keywords: ['obra', 'pós-obra', 'comercial', 'galpão'] }
    },
    'Montador': {
        simples: { min: 50, max: 100, keywords: ['prateleira', 'quadro', 'cadeira', 'suporte', 'tv'] },
        media: { min: 100, max: 200, keywords: ['armário', 'estante', 'guarda-roupa', 'mesa'] },
        complexa: { min: 200, max: 450, keywords: ['planejada', 'planejado', 'cozinha', 'completo'] }
    }
};

const PALAVRAS_URGENCIA = ['urgente', 'agora', 'socorro', 'vazando muito', 'inundando', 'fogo', 'desespero', 'rápido'];
const PALAVRAS_ESCALA = ['vários', 'varios', 'todos', 'toda', 'completo', 'grande quantidade', 'tudo'];

/**
 * Analisa o problema com base na categoria e texto descritivo e retorna estimativas de preço.
 * 
 * @param {String} categoria Categoria do serviço (Ex: 'Elétrica')
 * @param {String} descricao Descrição escrita pelo cliente
 * @returns {Object} Estimativa com { preco_minimo, preco_maximo, preco_sugerido, complexidade, fatores }
 */
const analisarProblema = (categoria, descricao) => {
    // Normalização
    const descNormalizada = (descricao || '').toLowerCase();
    
    // Tratamento para variações de nome que vêm do Frontend
    const chavesDisponiveis = Object.keys(DICIONARIO_CATEGORIAS);
    const cat = chavesDisponiveis.find(k => k.toLowerCase() === categoria.toLowerCase()) || categoria;

    // Valores Default se não encontrar nada (fallback genérico)
    let minBase = 50;
    let maxBase = 150;
    let complexidadeDetectada = 'desconhecida';
    let fatoresDetectados = [];

    // Tentar identificar complexidade na categoria
    if (DICIONARIO_CATEGORIAS[cat]) {
        let maiorComplexidade = -1; // 0=simples, 1=media, 2=complexa
        
        // Complexa
        if (DICIONARIO_CATEGORIAS[cat].complexa.keywords.some(k => descNormalizada.includes(k))) {
            maiorComplexidade = 2;
        } 
        // Media
        else if (DICIONARIO_CATEGORIAS[cat].media.keywords.some(k => descNormalizada.includes(k))) {
            maiorComplexidade = 1;
        } 
        // Simples
        else if (DICIONARIO_CATEGORIAS[cat].simples.keywords.some(k => descNormalizada.includes(k))) {
            maiorComplexidade = 0;
        }

        if (maiorComplexidade === 2) {
            minBase = DICIONARIO_CATEGORIAS[cat].complexa.min;
            maxBase = DICIONARIO_CATEGORIAS[cat].complexa.max;
            complexidadeDetectada = 'complexa';
        } else if (maiorComplexidade === 1) {
            minBase = DICIONARIO_CATEGORIAS[cat].media.min;
            maxBase = DICIONARIO_CATEGORIAS[cat].media.max;
            complexidadeDetectada = 'media';
        } else if (maiorComplexidade === 0) {
            minBase = DICIONARIO_CATEGORIAS[cat].simples.min;
            maxBase = DICIONARIO_CATEGORIAS[cat].simples.max;
            complexidadeDetectada = 'simples';
        } else {
            // Usa média ponderada se não identificar palavras-chave
            minBase = (DICIONARIO_CATEGORIAS[cat].simples.min + DICIONARIO_CATEGORIAS[cat].media.min) / 2;
            maxBase = (DICIONARIO_CATEGORIAS[cat].media.max + DICIONARIO_CATEGORIAS[cat].complexa.max) / 2;
            complexidadeDetectada = 'media_padrao';
        }
    }

    // Aplicação de multiplicadores
    let fatorUrgencia = 1.0;
    let fatorEscala = 1.0;

    if (PALAVRAS_URGENCIA.some(k => descNormalizada.includes(k))) {
        fatorUrgencia = 1.15; // +15%
        fatoresDetectados.push('urgência (+15%)');
    }

    if (PALAVRAS_ESCALA.some(k => descNormalizada.includes(k))) {
        fatorEscala = 1.20; // +20%
        fatoresDetectados.push('larga escala (+20%)');
    }

    let minCalculado = minBase * fatorUrgencia * fatorEscala;
    let maxCalculado = maxBase * fatorUrgencia * fatorEscala;

    // Adiciona a Taxa de Deslocamento Fixa do HELPI (R$ 40)
    minCalculado += TAXA_DESLOCAMENTO;
    maxCalculado += TAXA_DESLOCAMENTO;

    // Arredondamento para números bonitos (multiplos de 5 ou 10 fica melhor)
    minCalculado = Math.ceil(minCalculado / 5) * 5;
    maxCalculado = Math.ceil(maxCalculado / 5) * 5;

    const sugerido = Math.ceil((minCalculado + maxCalculado) / 2);

    return {
        preco_minimo: minCalculado,
        preco_maximo: maxCalculado,
        preco_sugerido: sugerido,
        complexidade: complexidadeDetectada,
        fatores_detectados: fatoresDetectados,
        taxa_deslocamento_inclusa: TAXA_DESLOCAMENTO
    };
};

module.exports = {
    analisarProblema
};
