const pool = require('../config/database');

const migrate = async () => {
    const client = await pool.connect();
    try {
        console.log('Migrating chamados_express...');
        await client.query(`
            ALTER TABLE chamados_express
            ADD COLUMN IF NOT EXISTS valor_estimado_min DECIMAL(10,2),
            ADD COLUMN IF NOT EXISTS valor_estimado_max DECIMAL(10,2),
            ADD COLUMN IF NOT EXISTS valor_cobrado DECIMAL(10,2),
            ADD COLUMN IF NOT EXISTS pagamento_status VARCHAR(20) DEFAULT 'pendente';
        `);
        console.log('Migration successful.');
    } catch (e) {
        console.error('Migration failed:', e);
    } finally {
        client.release();
        pool.end();
    }
};

migrate();
