// =============================================================
// HELPI - Configuração Global do Jest
// =============================================================

module.exports = {
  // Ambiente: Node.js (não browser)
  testEnvironment: 'node',

  // Timeout generoso para testes de integração (DB, sockets)
  testTimeout: 15000,

  // Setup global (carrega .env, define helpers)
  setupFiles: ['./tests/setup.js'],

  // Padrão de busca de ficheiros de teste
  testMatch: ['**/tests/**/*.test.js'],

  // Ignora node_modules e build artifacts
  testPathIgnorePatterns: ['/node_modules/'],

  // Cobertura: quais ficheiros cobrir
  collectCoverageFrom: [
    'src/controllers/**/*.js',
    'src/middlewares/**/*.js',
    'src/utils/**/*.js',
    '!src/utils/logger.js',
    '!src/config/**',
  ],

  // Relatório de cobertura
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'text-summary', 'lcov'],

  // Roda testes em série para evitar conflitos de BD
  // (override por script para unit tests paralelos)
  maxWorkers: 1,

  // Verbose por padrão para CI
  verbose: true,

  // Força saída após testes (evita hang por conexões de pool do Express/pg)
  forceExit: true,
};
