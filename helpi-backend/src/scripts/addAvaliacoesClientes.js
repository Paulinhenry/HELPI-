require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

async function main() {
    try {
        console.log('⏳ Adicionando colunas de avaliações na tabela clientes...');
        
        await pool.query(`
            ALTER TABLE clientes
            ADD COLUMN IF NOT EXISTS nota_media DECIMAL(3,2) DEFAULT 0.00,
            ADD COLUMN IF NOT EXISTS total_avaliacoes INTEGER DEFAULT 0;
        `);

        console.log('✅ Colunas adicionadas com sucesso!');
    } catch (err) {
        console.error('❌ Erro:', err);
    } finally {
        await pool.end();
    }
}

main();
