/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
  const hasTable = await knex.schema.hasTable('mensagens_chat');
  if (!hasTable) {
    await knex.schema.createTable('mensagens_chat', (table) => {
      table.uuid('id').primary().defaultTo(knex.raw('uuid_generate_v4()'));
      table.uuid('chamado_id').notNullable().references('id').inTable('chamados_express').onDelete('CASCADE');
      
      table.uuid('remetente_id').notNullable();
      table.string('tipo_remetente').notNullable(); // 'cliente' ou 'profissional'
      
      table.text('texto').notNullable();
      table.timestamp('criado_em').defaultTo(knex.fn.now());

      // Opcional, para ajudar na velocidade do fetch de mensagens
      table.index('chamado_id');
      table.index('criado_em');
    });
  }
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
  await knex.schema.dropTableIfExists('mensagens_chat');
};
