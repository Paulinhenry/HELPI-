const pool = require('../config/database');

const criarArquiteturaOnDemand = async () => {
    const cliente = await pool.connect();
    try {
        console.log('⏳ A preparar a arquitetura On-Demand (Estilo Uber)...');

        // 1. Atualizar a tabela de profissionais com GPS e Status Online
        console.log('📡 A adicionar sistema de localização aos profissionais...');
        await cliente.query(`
            ALTER TABLE profissionais
            ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false,
            ADD COLUMN IF NOT EXISTS latitude_atual DECIMAL(10,8),
            ADD COLUMN IF NOT EXISTS longitude_atual DECIMAL(11,8);
        `);
        console.log('✅ Profissionais agora podem ficar "Online" e partilhar a localização!');

        // 2. Criar a tabela de Chamados Express
        console.log('🚨 A construir a tabela de Chamados Express...');
        await cliente.query(`
            CREATE TABLE IF NOT EXISTS chamados_express (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
                
                -- Fica nulo até um profissional aceitar a corrida
                profissional_id UUID REFERENCES profissionais(id) ON DELETE SET NULL, 
                
                categoria_solicitada VARCHAR(50) NOT NULL,
                problema_descricao TEXT NOT NULL,
                
                -- Localização exata da emergência do cliente
                latitude_destino DECIMAL(10,8) NOT NULL,
                longitude_destino DECIMAL(11,8) NOT NULL,
                
                -- Status do Pedido (procurando, a_caminho, em_servico, finalizado, cancelado)
                status VARCHAR(30) DEFAULT 'procurando_profissional',
                
                -- Relógio SLA (O controlo rigoroso para garantir o serviço em 1 hora)
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                aceite_em TIMESTAMP WITH TIME ZONE,
                chegou_ao_local_em TIMESTAMP WITH TIME ZONE,
                finalizado_em TIMESTAMP WITH TIME ZONE,
                
                valor_estimado DECIMAL(10,2),
                valor_estimado_min DECIMAL(10,2),
                valor_estimado_max DECIMAL(10,2),
                valor_cobrado DECIMAL(10,2),
                pagamento_status VARCHAR(20) DEFAULT 'pendente'
            );
        `);
        console.log('✅ Tabela "chamados_express" criada com sucesso!');
        console.log('🚀 O motor on-demand do Helpi está oficialmente pronto na nuvem!');

    } catch (erro) {
        console.error('❌ Erro crítico ao criar arquitetura express:', erro);
    } finally {
        cliente.release();
        pool.end();
    }
};

criarArquiteturaOnDemand();