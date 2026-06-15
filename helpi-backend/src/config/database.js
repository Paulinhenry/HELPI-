// =============================================================
// HELPI - Configuração do Pool de Conexões PostgreSQL
// Gerencia as conexões com o banco de dados de forma eficiente.
// =============================================================

const { Pool } = require('pg');
const logger = require('../utils/logger');
require('dotenv').config();

const isProduction = process.env.NODE_ENV === 'production';

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },

    // Configurações de resiliência do pool
    max: parseInt(process.env.DB_POOL_MAX, 10) || 20,              // Máximo de conexões simultâneas
    idleTimeoutMillis: 30000,           // Fecha conexões ociosas após 30s
    connectionTimeoutMillis: 5000,      // Timeout de 5s para obter uma conexão
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