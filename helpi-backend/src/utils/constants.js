// =============================================================
// HELPI - Constantes Globais
// =============================================================

const TAXA_DESLOCAMENTO = 40.00;

// Mapeamento de categorias: o que o Cliente vê -> o que o Profissional é
const MAPA_CATEGORIAS = {
    'Elétrica': 'Eletricista',
    'Hidráulica': 'Encanador',
    'Chaveiro': 'Chaveiro',
    'Limpeza': 'Limpeza',
    'Montador': 'Montador'
};

// Configuração das categorias para o frontend
const CATEGORIAS_FRONTEND = [
    { nome: 'Elétrica', icone: 'electrical_services', cor: 'orange' },
    { nome: 'Hidráulica', icone: 'plumbing', cor: 'blue' },
    { nome: 'Chaveiro', icone: 'key', cor: 'amber' },
    { nome: 'Limpeza', icone: 'cleaning_services', cor: 'teal' },
    { nome: 'Montador', icone: 'handyman', cor: 'blueGrey' }
];

module.exports = {
    TAXA_DESLOCAMENTO,
    MAPA_CATEGORIAS,
    CATEGORIAS_FRONTEND
};
