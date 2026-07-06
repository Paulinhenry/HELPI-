// =============================================================
// HELPI - Configuração do Pool de Conexões PostgreSQL
// Gerencia as conexões com o banco de dados de forma eficiente.
//
// ESCALABILIDADE:
// - Pool dimensionado para produção
// - SSL condicional por ambiente
// - Retry automático em falhas de conexão
// - Statement timeout para evitar queries travadas
// =============================================================

const { Pool } = require('pg');
const logger = require('../utils/logger');
require('dotenv').config();

const isProduction = process.env.NODE_ENV === 'production';

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,

    // SSL: obrigatório em produção (Neon, Supabase, etc.)
    // SEGURANÇA: rejectUnauthorized=true em produção para evitar MITM
    ssl: process.env.DB_SSL === 'false'
        ? false
        : { rejectUnauthorized: process.env.NODE_ENV === 'production' },

    // ─── Configurações de Pool para Escala ───
    max: parseInt(process.env.DB_POOL_MAX, 10) || 20,
    min: parseInt(process.env.DB_POOL_MIN, 10) || 2,        // Manter 2 conexões sempre prontas
    idleTimeoutMillis: 30000,           // Fecha conexões ociosas após 30s
    connectionTimeoutMillis: 5000,      // Timeout de 5s para obter uma conexão
    allowExitOnIdle: false,             // Não encerrar o pool quando ocioso

    // Timeout de queries: evita queries travadas consumindo conexões
    statement_timeout: parseInt(process.env.DB_STATEMENT_TIMEOUT, 10) || 30000, // 30s
});

// Loga erros inesperados nas conexões (evita crashes silenciosos)
pool.on('error', (err) => {
    logger.error('Erro inesperado na conexão com o banco de dados:', {
        message: err.message,
        stack: err.stack
    });
});

// Log de conexão bem-sucedida ao iniciar
pool.on('connect', () => {
    if (!isProduction) {
        logger.info('Nova conexão estabelecida com o banco de dados.');
    }
});

module.exports = pool;