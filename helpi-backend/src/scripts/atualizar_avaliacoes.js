const pool = require('../config/database');

const atualizarTabelaAvaliacoes = async () => {
    const cliente = await pool.connect();
    try {
        console.log('⭐ A atualizar o sistema de Avaliações (Bi-direcional)...');
        
        await cliente.query('DROP TABLE IF EXISTS avaliacoes CASCADE;');

        await cliente.query(`
            CREATE TABLE avaliacoes (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                chamado_id UUID REFERENCES chamados_express(id) ON DELETE CASCADE,
                
                -- Polimorfismo Bi-direcional
                avaliador_id UUID NOT NULL,
                avaliador_tipo VARCHAR(20) CHECK (avaliador_tipo IN ('cliente', 'profissional')) NOT NULL,
                
                avaliado_id UUID NOT NULL,
                avaliado_tipo VARCHAR(20) CHECK (avaliado_tipo IN ('cliente', 'profissional')) NOT NULL,
                
                -- A nota tem de ser obrigatoriamente entre 1 e 5
                nota INTEGER CHECK (nota >= 1 AND nota <= 5) NOT NULL,
                tags JSONB DEFAULT '[]'::jsonb,
                comentario TEXT,
                
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                
                -- Regra de Ouro: Bloqueio Único (Um ator só avalia um chamado uma vez)
                CONSTRAINT unique_avaliacao_por_chamado UNIQUE (chamado_id, avaliador_tipo)
            );
        `);
        console.log('✅ Tabela "avaliacoes" atualizada para Motor de Confiança Bi-direcional!');

    } catch (erro) {
        console.error('❌ Erro crítico ao atualizar a tabela:', erro);
    } finally {
        cliente.release();
        pool.end();
    }
};

atualizarTabelaAvaliacoes();
