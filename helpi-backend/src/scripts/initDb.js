const pool = require('../config/database');

const criarTabelas = async () => {
    const cliente = await pool.connect();
    try {
        console.log('⏳ A construir infraestrutura de nível Enterprise na nuvem...');

        // 0. Limpeza: Apaga as tabelas antigas simples para aplicar a nova estrutura
        await cliente.query('DROP TABLE IF EXISTS enderecos_clientes CASCADE');
        await cliente.query('DROP TABLE IF EXISTS clientes CASCADE');
        await cliente.query('DROP TABLE IF EXISTS profissionais CASCADE');

        // 1. Tabela de Clientes (Perfil e Segurança)
        await cliente.query(`
            CREATE TABLE clientes (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                nome VARCHAR(100) NOT NULL,
                cpf VARCHAR(14) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                senha VARCHAR(255) NOT NULL,
                telefone VARCHAR(20) NOT NULL,
                nota_media DECIMAL(3,2) DEFAULT 0.00,
                total_avaliacoes INTEGER DEFAULT 0,
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log('✅ Tabela "clientes" (Perfil) criada com sucesso!');

        // 2. Tabela de Endereços (A Lógica do iFood: 1 cliente -> N endereços)
        await cliente.query(`
            CREATE TABLE enderecos_clientes (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                cliente_id UUID REFERENCES clientes(id) ON DELETE CASCADE,
                apelido VARCHAR(50) DEFAULT 'Casa', -- Ex: Casa, Trabalho, Casa da Namorada
                cep VARCHAR(9) NOT NULL,
                logradouro VARCHAR(255) NOT NULL,
                numero VARCHAR(20) NOT NULL,
                complemento VARCHAR(100),
                bairro VARCHAR(100) NOT NULL,
                cidade VARCHAR(100) NOT NULL,
                estado CHAR(2) NOT NULL,
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log('✅ Tabela "enderecos_clientes" (Logística) criada com sucesso!');

        // 3. Tabela de Profissionais (O Catálogo de Serviços)
        await cliente.query(`
            CREATE TABLE profissionais (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                nome VARCHAR(100) NOT NULL,
                cpf_cnpj VARCHAR(18) UNIQUE NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                senha VARCHAR(255) NOT NULL,
                telefone VARCHAR(20) NOT NULL,
                categoria VARCHAR(50) NOT NULL,
                biografia TEXT, -- Para o profissional "vender" o seu trabalho
                taxa_visita DECIMAL(10,2) DEFAULT 0.00, -- Ex: Valor cobrado apenas pela deslocação
                nota_media DECIMAL(3,2) DEFAULT 0.00,
                total_avaliacoes INTEGER DEFAULT 0,
                status VARCHAR(20) DEFAULT 'pendente_aprovacao', -- Para aprovares quem entra
                criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log('✅ Tabela "profissionais" (Catálogo) criada com sucesso!');

    } catch (erro) {
        console.error('❌ Erro crítico ao desenhar a base de dados:', erro);
    } finally {
        cliente.release();
        pool.end();
    }
};

criarTabelas();