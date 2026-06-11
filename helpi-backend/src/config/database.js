const { Pool } = require('pg');
require('dotenv').config();

// O 'Pool' gere as ligações simultâneas à tua base de dados
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: {
        rejectUnauthorized: false // Fundamental para conexões seguras na nuvem (Neon)
    }
});

module.exports = pool;