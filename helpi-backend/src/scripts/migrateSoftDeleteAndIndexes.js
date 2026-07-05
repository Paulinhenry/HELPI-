// =============================================================
// HELPI - Migration: Soft-Delete + Índices de Performance
//
// Este script adiciona:
// 1. Colunas de soft-delete (deletado_em, atualizado_em)
// 2. Índices compostos para queries frequentes
// 3. Índices para paginação e filtros
//
// Executar: node src/scripts/migrateSoftDeleteAndIndexes.js
// =============================================================

const pool = require('../config/database');

const executarMigration = async () => {
    const cliente = await pool.connect();
    try {
        console.log('⏳ A executar migration: Soft-Delete + Índices de Performance...\n');

        await cliente.query('BEGIN');

        // ─── 1. SOFT-DELETE: Adicionar colunas ───────────────────
        console.log('🗑️  A adicionar sistema de Soft-Delete...');

        await cliente.query(`
            ALTER TABLE clientes
            ADD COLUMN IF NOT EXISTS deletado_em TIMESTAMP WITH TIME ZONE DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
        `);

        await cliente.query(`
            ALTER TABLE profissionais
            ADD COLUMN IF NOT EXISTS deletado_em TIMESTAMP WITH TIME ZONE DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
        `);

        await cliente.query(`
            ALTER TABLE chamados_express
            ADD COLUMN IF NOT EXISTS cancelado_em TIMESTAMP WITH TIME ZONE DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS motivo_cancelamento TEXT DEFAULT NULL;
        `);

        console.log('✅ Colunas de soft-delete adicionadas!\n');

        // ─── 2. CORRIGIR nota_media DECIMAL(3,2) → DECIMAL(3,1) ──
        console.log('🔧 A corrigir tipo da coluna nota_media...');
        await cliente.query(`
            ALTER TABLE profissionais 
            ALTER COLUMN nota_media TYPE DECIMAL(3,2);
        `);
        console.log('✅ Coluna nota_media corrigida!');

        // ─── 3. ÍNDICES DE PERFORMANCE ───────────────────────────
        console.log('⚡ A criar índices de performance...');

        // Chamados: filtrar por status é a query mais frequente
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_chamados_status
            ON chamados_express (status);
        `);

        // Chamados: "meus chamados" (lista do cliente)
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_chamados_cliente
            ON chamados_express (cliente_id, criado_em DESC);
        `);

        // Chamados: chamados do profissional
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_chamados_profissional
            ON chamados_express (profissional_id, criado_em DESC);
        `);

        // Profissionais: busca por categoria + status (listagem pública)
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_profissionais_categoria_status
            ON profissionais (categoria, status) WHERE deletado_em IS NULL;
        `);

        // Profissionais: busca de online (para chamados express)
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_profissionais_online
            ON profissionais (is_online, categoria, status)
            WHERE is_online = true AND deletado_em IS NULL;
        `);

        // Clientes: busca por email (login)
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_clientes_email
            ON clientes (email) WHERE deletado_em IS NULL;
        `);

        // Profissionais: busca por email (login)
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_profissionais_email
            ON profissionais (email) WHERE deletado_em IS NULL;
        `);

        // Avaliações: média do profissional
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS idx_avaliacoes_avaliado
            ON avaliacoes (avaliado_id, nota);
        `);

        await cliente.query('COMMIT');

        console.log('✅ Todos os índices criados com sucesso!');
        console.log('\n🚀 Migration concluída! O Helpi está pronto para escalar.\n');

        // Exibir índices criados
        const indices = await pool.query(`
            SELECT tablename, indexname
            FROM pg_indexes
            WHERE schemaname = 'public'
            AND indexname LIKE 'idx_%'
            ORDER BY tablename, indexname;
        `);

        console.log('📊 Índices ativos:');
        indices.rows.forEach(idx => {
            console.log(`   ${idx.tablename} → ${idx.indexname}`);
        });

    } catch (erro) {
        await cliente.query('ROLLBACK');
        console.error('❌ Erro na migration:', erro.message);
    } finally {
        cliente.release();
        pool.end();
    }
};

executarMigration();
