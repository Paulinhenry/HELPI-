const pool = require('../config/database');

const criarTabelaAvaliacoes = async () => {
    const cliente = await pool.connect();
    try {
        console.log('⭐ A preparar o sistema de Avaliações (5 Estrelas)...');

        await cliente.query(`
            CREATE TABLE IF NOT EXISTS avaliacoes (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                
                -- Relacionamentos: Quem avaliou, quem foi avaliado e qual foi o serviço
                chamado_id UUID REFERENCES chamados_express(id) ON DELETE CASCADE UNIQUE,
                cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
                profissional_id UUID REFERENCES profissionais(id) ON DELETE CASCADE,
                
                -- A nota tem de ser obrigatoriamente entre 1 e 5
                nota INTEGER CHECK (nota >= 1 AND nota <= 5) NOT NULL,
                comentario TEXT,
                
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log('✅ Tabela "avaliacoes" criada com sucesso!');
        console.log('🛡️ Regra ativada: Um serviço só pode ser avaliado uma única vez (UNIQUE).');

    } catch (erro) {
        console.error('❌ Erro crítico ao criar a tabela:', erro);
    } finally {
        cliente.release();
        pool.end();
    }
};

criarTabelaAvaliacoes();