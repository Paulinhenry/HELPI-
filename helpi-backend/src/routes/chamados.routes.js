// =============================================================
// HELPI - Rotas de Chamados Express (On-Demand)
// POST   /api/chamados              → Criar chamado (cliente)
// PUT    /api/chamados/:id/aceitar   → Aceitar chamado (profissional)
// PUT    /api/chamados/:id/chegada   → Registrar chegada (profissional)
// PUT    /api/chamados/:id/finalizar → Finalizar serviço (profissional)
// =============================================================

const express = require('express');
const router = express.Router();
const chamadosController = require('../controllers/chamados.controller');
const authCliente = require('../middlewares/authCliente');
const authProfissional = require('../middlewares/authProfissional');
const { validarCriacaoChamado } = require('../middlewares/validators/chamadoValidator');
const { validarUUID } = require('../middlewares/validators/uuidValidator');

/**
 * @openapi
 * /api/chamados:
 *   get:
 *     summary: Listar chamados do cliente autenticado (paginado)
 *     tags: [Chamados]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: cursor
 *         schema:
 *           type: string
 *         description: Cursor para paginação (valor de criado_em do último item)
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           default: 20
 *           maximum: 50
 *         description: Número de resultados por página
 *     responses:
 *       '200':
 *         description: Lista de chamados do cliente com paginação
 *   post:
 *     summary: Criar um novo chamado de emergência
 *     tags: [Chamados]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - categoria_solicitada
 *               - problema_descricao
 *               - latitude_destino
 *               - longitude_destino
 *             properties:
 *               categoria_solicitada:
 *                 type: string
 *                 example: "Eletricista"
 *               problema_descricao:
 *                 type: string
 *                 example: "Curto-circuito na sala de estar"
 *               latitude_destino:
 *                 type: number
 *                 example: -23.557434
 *               longitude_destino:
 *                 type: number
 *                 example: -46.662153
 *     responses:
 *       '201':
 *         description: Chamado criado com sucesso
 *       '401':
 *         description: Token não fornecido ou inválido
 *       '403':
 *         description: Acesso permitido apenas para clientes
 *       '404':
 *         description: Nenhum profissional disponível na região
 *
 * /api/chamados/{id}/aceitar:
 *   put:
 *     summary: Profissional aceita o chamado
 *     tags: [Chamados]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       '200':
 *         description: Chamado aceite com sucesso
 *       '400':
 *         description: Chamado já aceite ou cancelado
 *       '401':
 *         description: Token inválido
 *       '403':
 *         description: Acesso permitido apenas para profissionais
 *       '404':
 *         description: Chamado não encontrado
 *
 * /api/chamados/{id}/chegada:
 *   put:
 *     summary: Profissional avisa que chegou ao local
 *     tags: [Chamados]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       '200':
 *         description: Chegada registada com sucesso
 *       '400':
 *         description: Status inválido para esta ação
 *       '403':
 *         description: Sem permissão para alterar este chamado
 *
 * /api/chamados/{id}/finalizar:
 *   put:
 *     summary: Finalizar o serviço prestado
 *     tags: [Chamados]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       '200':
 *         description: Serviço finalizado com sucesso
 *       '400':
 *         description: Status inválido para esta ação
 *       '403':
 *         description: Sem permissão para finalizar este chamado
 */

router.get('/', authCliente, chamadosController.listarMeusChamados);
router.post('/', authCliente, validarCriacaoChamado, chamadosController.criarChamado);

// --- CRASH RECOVERY: Verifica se o profissional tem chamado ativo ---
// IMPORTANTE: Deve ficar ANTES das rotas com :id para o Express não confundir 'em-andamento' com um UUID
router.get('/em-andamento', authProfissional, chamadosController.verificarChamadoAtivo);

// --- CRASH RECOVERY CLIENTE: Verifica se o cliente tem chamado ativo ---
router.get('/meu-ativo', authCliente, chamadosController.verificarChamadoAtivoCliente);

// --- NOVA ROTA DE CANCELAMENTO AQUI ---
router.patch('/:id/cancelar', authCliente, validarUUID, chamadosController.cancelarChamado);

router.put('/:id/aceitar', authProfissional, validarUUID, chamadosController.aceitarChamado);
router.put('/:id/chegada', authProfissional, validarUUID, chamadosController.registrarChegada);
router.put('/:id/finalizar', authProfissional, validarUUID, chamadosController.finalizarChamado);

module.exports = router;