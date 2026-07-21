const knex = require('knex')(require('./knexfile').development);

async function up() {
  const hasTable = await knex.schema.hasTable('mensagens_chat');
  if (!hasTable) {
    await knex.schema.createTable('mensagens_chat', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('uuid_generate_v4()'));
      table.uuid('chamado_id').notNullable().references('id').inTable('chamados_express').onDelete('CASCADE');
      
      table.uuid('remetente_id').notNullable();
      table.string('tipo_remetente').notNullable();
      
      table.text('texto').notNullable();
      table.timestamp('criado_em').defaultTo(knex.fn.now());

      table.index('chamado_id');
      table.index('criado_em');
    });
    console.log('Tabela mensagens_chat criada com sucesso.');
  } else {
    console.log('Tabela mensagens_chat já existe.');
  }
  process.exit(0);
}

up().catch(console.error);
