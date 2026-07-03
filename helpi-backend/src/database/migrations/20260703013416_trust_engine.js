/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  // Garantir a extensão para geração de UUIDs nativos do PostGIS/PostgreSQL
  await knex.raw('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"');

  // 1. Tabela Clientes - Criar se não existir (para o CI), ou apenas alterar (em Produção)
  const hasClientes = await knex.schema.hasTable('clientes');
  if (!hasClientes) {
    await knex.schema.createTable('clientes', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('uuid_generate_v4()'));
      table.string('nome').notNullable();
      table.string('email').unique().notNullable();
      table.string('senha');
    });
  }
  
  // Adicionar campos do Trust Engine em Clientes
  const hasNotaCliente = await knex.schema.hasColumn('clientes', 'nota_media');
  if (!hasNotaCliente) {
    await knex.schema.alterTable('clientes', (table) => {
      table.decimal('nota_media', 3, 2).defaultTo(5.00);
      table.integer('total_avaliacoes').defaultTo(0);
    });
  }

  // 2. Tabela Profissionais
  const hasProfissionais = await knex.schema.hasTable('profissionais');
  if (!hasProfissionais) {
    await knex.schema.createTable('profissionais', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('uuid_generate_v4()'));
      table.string('nome').notNullable();
      table.string('email').unique().notNullable();
      table.string('senha');
      table.string('status').defaultTo('ativo');
    });
  }
  
  const hasNotaProf = await knex.schema.hasColumn('profissionais', 'nota_media');
  if (!hasNotaProf) {
    await knex.schema.alterTable('profissionais', (table) => {
      table.decimal('nota_media', 3, 2).defaultTo(5.00);
      table.integer('total_avaliacoes').defaultTo(0);
    });
  }

  // 3. Tabela Chamados Express (apenas para que a Foreign Key funcione no CI)
  const hasChamados = await knex.schema.hasTable('chamados_express');
  if (!hasChamados) {
    await knex.schema.createTable('chamados_express', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('uuid_generate_v4()'));
      table.uuid('cliente_id').references('id').inTable('clientes').onDelete('CASCADE');
      table.uuid('profissional_id').references('id').inTable('profissionais').onDelete('CASCADE');
      table.string('status').notNullable();
    });
  }

  // 4. A Tabela Mestra: Avaliacoes
  const hasAvaliacoes = await knex.schema.hasTable('avaliacoes');
  if (!hasAvaliacoes) {
    await knex.schema.createTable('avaliacoes', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('uuid_generate_v4()'));
      table.uuid('chamado_id').notNullable().references('id').inTable('chamados_express').onDelete('CASCADE');
      
      table.uuid('avaliador_id').notNullable();
      table.string('avaliador_tipo').notNullable(); // 'cliente' ou 'profissional'
      
      table.uuid('avaliado_id').notNullable();
      table.string('avaliado_tipo').notNullable();
      
      table.smallint('nota').notNullable();
      table.jsonb('tags').defaultTo('[]'); // Usando JSONB para super flexibilidade e rapidez
      table.text('comentario');
      
      table.timestamp('criado_em').defaultTo(knex.fn.now());

      // Regra de Ouro (Bloqueio Único)
      table.unique(['chamado_id', 'avaliador_tipo']);
    });
    
    // Check Constraint nativo do PostgreSQL para a nota
    await knex.raw('ALTER TABLE avaliacoes ADD CONSTRAINT check_nota_range CHECK (nota >= 1 AND nota <= 5)');
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  // Num ambiente real de produção faríamos rollback controlado, aqui removemos a estrutura do Trust Engine.
  await knex.schema.dropTableIfExists('avaliacoes');
  
  const hasNotaCliente = await knex.schema.hasColumn('clientes', 'nota_media');
  if (hasNotaCliente) {
    await knex.schema.alterTable('clientes', (table) => {
      table.dropColumn('nota_media');
      table.dropColumn('total_avaliacoes');
    });
  }

  const hasNotaProf = await knex.schema.hasColumn('profissionais', 'nota_media');
  if (hasNotaProf) {
    await knex.schema.alterTable('profissionais', (table) => {
      table.dropColumn('nota_media');
      table.dropColumn('total_avaliacoes');
    });
  }
};
