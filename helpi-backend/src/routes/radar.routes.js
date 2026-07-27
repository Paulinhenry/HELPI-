const express = require('express');
const router = express.Router();
const surgePricingService = require('../services/surgePricing.service');
const { authProfissional } = require('../middlewares/auth');

/**
 * @swagger
 * /api/v1/radar/heatmap:
 *   get:
 *     summary: Retorna as zonas quentes de alta demanda (Heatmap e Surge Pricing)
 *     tags: [Radar]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Array com as zonas ativas.
 */
router.get('/heatmap', authProfissional, async (req, res, next) => {
    try {
        const zonas = await surgePricingService.obterZonasQuentes();
        return res.json({
            mensagem: 'Zonas quentes recuperadas com sucesso.',
            zonas
        });
    } catch (erro) {
        next(erro);
    }
});

module.exports = router;
