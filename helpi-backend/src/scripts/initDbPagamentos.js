const pool = require('../config/database');

const criarTabelaPagamentos = async () => {
    const cliente = await pool.connect();
    try {
        console.log('⏳ Criando tabela de pagamentos...');

        await cliente.query(`
            CREATE TABLE IF NOT EXISTS pagamentos (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                chamado_id UUID REFERENCES chamados_express(id) UNIQUE NOT NULL,
                
                -- IDs do Mercado Pago
                mp_payment_id VARCHAR(100),
                mp_preference_id VARCHAR(100),
                
                -- Valores
                valor_total DECIMAL(10,2) NOT NULL,
                valor_profissional DECIMAL(10,2) NOT NULL,
                valor_plataforma DECIMAL(10,2) NOT NULL,
                
                status VARCHAR(30) DEFAULT 'pendente',
                metodo_pagamento VARCHAR(20),
                
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                pago_em TIMESTAMP WITH TIME ZONE,
                liberado_em TIMESTAMP WITH TIME ZONE
            );
        `);
        console.log('✅ Tabela "pagamentos" criada com sucesso!');

    } catch (erro) {
        console.error('❌ Erro crítico ao criar tabela de pagamentos:', erro);
    } finally {
        cliente.release();
        pool.end();
    }
};

criarTabelaPagamentos();
