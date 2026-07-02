// =============================================================
// HELPI - Setup Global de Testes
// Carrega variáveis de ambiente e expõe helpers reutilizáveis
// =============================================================

require('dotenv').config();

// Garante que existe um JWT_SECRET para testes (mesmo sem .env)
if (!process.env.JWT_SECRET) {
  process.env.JWT_SECRET = 'helpi-test-secret-jwt-2024';
}

// Garante que o NODE_ENV é 'test'
process.env.NODE_ENV = 'test';

const jwt = require('jsonwebtoken');

// ─── HELPERS DE AUTENTICAÇÃO ────────────────────────────────
// Gera tokens JWT válidos para simular clientes e profissionais nos testes

/**
 * Gera um Access Token de Cliente para testes
 * @param {string} clienteId - UUID ou ID do cliente
 * @returns {string} Token JWT válido
 */
const gerarTokenCliente = (clienteId = 'test-cliente-uuid-001') => {
  return jwt.sign(
    { id: clienteId, tipo: 'cliente', tokenType: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
};

/**
 * Gera um Access Token de Profissional para testes
 * @param {string} profissionalId - UUID ou ID do profissional
 * @returns {string} Token JWT válido
 */
const gerarTokenProfissional = (profissionalId = 'test-profissional-uuid-001') => {
  return jwt.sign(
    { id: profissionalId, tipo: 'profissional', tokenType: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: '15m' }
  );
};

/**
 * Gera um Token JWT expirado (para testar rejeição)
 * @param {string} tipo - 'cliente' ou 'profissional'
 * @returns {string} Token JWT expirado
 */
const gerarTokenExpirado = (tipo = 'cliente') => {
  return jwt.sign(
    { id: 'test-expired-uuid', tipo, tokenType: 'access' },
    process.env.JWT_SECRET,
    { expiresIn: '0s' } // Expira imediatamente
  );
};

// Exporta os helpers para todos os testes
module.exports = {
  gerarTokenCliente,
  gerarTokenProfissional,
  gerarTokenExpirado,
};
