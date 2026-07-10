require('dotenv').config();

// =============================================================
// HELPI - Configuração do Knex.js (Migrations e Queries)
// =============================================================

module.exports = {
  development: {
    client: 'postgresql',
    connection: process.env.DATABASE_URL,
    pool: {
      min: 2,
      max: 10
    },
    migrations: {
      tableName: 'knex_migrations',
      directory: './src/database/migrations'
    },
    seeds: {
      directory: './src/database/seeds'
    }
  },

  test: {
    client: 'postgresql',
    connection: process.env.DATABASE_URL,
    pool: {
      min: 2,
      max: 10
    },
    migrations: {
      tableName: 'knex_migrations',
      directory: './src/database/migrations'
    },
    seeds: {
      directory: './src/database/seeds'
    }
  },

  production: {
    client: 'postgresql',
    connection: {
      connectionString: process.env.DATABASE_URL,
      ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: true }
    },
    pool: {
      min: 2,
      max: parseInt(process.env.DB_POOL_MAX, 10) || 20
    },
    migrations: {
      tableName: 'knex_migrations',
      directory: './src/database/migrations'
    }
  }
};
