/**
 * HELPI — Migration: Adicionar coluna FCM Token
 * Guarda o token do Firebase Cloud Messaging para push notifications
 * tanto nos profissionais como nos clientes.
 *
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.up = async function(knex) {
    // Adicionar fcm_token aos profissionais
    const hasFcmProf = await knex.schema.hasColumn('profissionais', 'fcm_token');
    if (!hasFcmProf) {
        await knex.schema.alterTable('profissionais', (table) => {
            table.text('fcm_token').nullable();
        });
    }

    // Adicionar fcm_token aos clientes
    const hasFcmCliente = await knex.schema.hasColumn('clientes', 'fcm_token');
    if (!hasFcmCliente) {
        await knex.schema.alterTable('clientes', (table) => {
            table.text('fcm_token').nullable();
        });
    }

    // Índice para busca rápida por token (cleanup de tokens inválidos)
    await knex.raw(`
        CREATE INDEX IF NOT EXISTS idx_profissionais_fcm_token
        ON profissionais (fcm_token)
        WHERE fcm_token IS NOT NULL
    `);

    await knex.raw(`
        CREATE INDEX IF NOT EXISTS idx_clientes_fcm_token
        ON clientes (fcm_token)
        WHERE fcm_token IS NOT NULL
    `);
};

/**
 * @param { import("knex").Knex } knex
 * @returns { Promise<void> }
 */
exports.down = async function(knex) {
    await knex.raw('DROP INDEX IF EXISTS idx_profissionais_fcm_token');
    await knex.raw('DROP INDEX IF EXISTS idx_clientes_fcm_token');

    const hasFcmProf = await knex.schema.hasColumn('profissionais', 'fcm_token');
    if (hasFcmProf) {
        await knex.schema.alterTable('profissionais', (table) => {
            table.dropColumn('fcm_token');
        });
    }

    const hasFcmCliente = await knex.schema.hasColumn('clientes', 'fcm_token');
    if (hasFcmCliente) {
        await knex.schema.alterTable('clientes', (table) => {
            table.dropColumn('fcm_token');
        });
    }
};
