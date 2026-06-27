const { analisarProblema } = require('../utils/precificador');
const { payment } = require('../config/mercadopago');
const pool = require('../config/database');
const crypto = require('crypto');
const logger = require('../utils/logger');


const estimarPreco = async (req, res, next) => {
    try {
        const { categoria, descricao } = req.body;

        if (!categoria) {
            return res.status(400).json({ erro: "Categoria é obrigatória para a estimativa." });
        }

        const estimativa = analisarProblema(categoria, descricao);

        return res.json({
            mensagem: "Estimativa calculada com sucesso",
            estimativa
        });
    } catch (erro) {
        next(erro);
    }
};

const processarPagamento = async (req, res, next) => {
    try {
        const { chamado_id, transaction_amount, token, description, installments, payment_method_id, issuer_id, payer } = req.body;
        const cliente_id = req.usuario.id;

        // 1. Validar Chamado
        const chamadoQuery = await pool.query(
            `SELECT id, valor_cobrado, profissional_id, status FROM chamados_express WHERE id = $1 AND cliente_id = $2`,
            [chamado_id, cliente_id]
        );

        if (chamadoQuery.rows.length === 0) {
            return res.status(404).json({ erro: 'Chamado não encontrado.' });
        }

        const chamado = chamadoQuery.rows[0];
        
        if (chamado.status !== 'finalizado') {
            return res.status(400).json({ erro: 'Apenas serviços finalizados podem ser pagos.' });
        }

        // Split Calculation (90/10)
        const valorTotal = parseFloat(chamado.valor_cobrado);
        const valorPlataforma = valorTotal * 0.10; // 10% HELPI
        const valorProfissional = valorTotal * 0.90; // 90% Profissional

        // 2. Criar Payment no Mercado Pago (Transparente)
        const requestOptions = {
            body: {
                transaction_amount: valorTotal,
                token: token,
                description: description || `Serviço Helpi - Chamado ${chamado_id.split('-')[0]}`,
                installments: installments || 1,
                payment_method_id: payment_method_id,
                issuer_id: issuer_id,
                payer: {
                    email: payer.email,
                    identification: payer.identification
                },
                // Marketplace Application Fee (Split)
                // application_fee: valorPlataforma // Removido para MVP se não tivermos setup avançado de marketplace MP
                // Nota: Para usar application_fee nativo do MP, o access_token usado tem de ser o da conta do Profissional, ou a plataforma recolhe tudo e distribui.
                // Como MVP de backend, faremos a plataforma receber tudo.
            }
        };

        const mpResponse = await payment.create(requestOptions);

        // 3. Guardar Pagamento na BD
        await pool.query(
            `INSERT INTO pagamentos (chamado_id, mp_payment_id, valor_total, valor_profissional, valor_plataforma, status, metodo_pagamento)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [
                chamado_id, 
                mpResponse.id.toString(), 
                valorTotal, 
                valorProfissional, 
                valorPlataforma, 
                mpResponse.status, // 'approved', 'in_process', 'rejected'
                payment_method_id
            ]
        );

        // Atualizar status do chamado se aprovado imediatamente
        if (mpResponse.status === 'approved') {
            await pool.query(`UPDATE chamados_express SET pagamento_status = 'pago' WHERE id = $1`, [chamado_id]);
            
            // Notificar Profissional
            const io = req.app.get('io');
            const profissionaisConectados = req.app.get('profissionaisConectados');
            if (io && profissionaisConectados) {
                const socketId = profissionaisConectados.get(chamado.profissional_id);
                if (socketId) {
                    io.to(socketId).emit('pagamento_confirmado', {
                        chamado_id,
                        valor: valorProfissional
                    });
                }
            }
        }

        return res.json({
            status: mpResponse.status,
            status_detail: mpResponse.status_detail,
            id: mpResponse.id,
            qr_code: mpResponse.point_of_interaction?.transaction_data?.qr_code,
            qr_code_base64: mpResponse.point_of_interaction?.transaction_data?.qr_code_base64
        });
        
    } catch (erro) {
        logger.error(`[PAGAMENTO] Erro: ${erro.message}`);
        next(erro);
    }
};

const webhookMercadoPago = async (req, res) => {
    try {
        let paymentId = null;
        
        // O Mercado Pago envia webhooks e IPNs em formatos diferentes
        if (req.body?.type === 'payment' && req.body?.data?.id) {
            paymentId = req.body.data.id;
        } else if (req.body?.action?.startsWith('payment.') && req.body?.data?.id) {
            paymentId = req.body.data.id;
        } else if (req.query?.topic === 'payment' && req.query?.id) {
            paymentId = req.query.id;
        }

        if (paymentId) {
            const mpPayment = await payment.get({ id: paymentId });
            
            if (mpPayment.status === 'approved') {
                // Atualizar BD
                const updateRes = await pool.query(
                    `UPDATE pagamentos SET status = 'approved', pago_em = CURRENT_TIMESTAMP 
                     WHERE mp_payment_id = $1 RETURNING chamado_id, valor_profissional`,
                    [paymentId.toString()]
                );
                
                if (updateRes.rows.length > 0) {
                    const chamado_id = updateRes.rows[0].chamado_id;
                    await pool.query(`UPDATE chamados_express SET pagamento_status = 'pago' WHERE id = $1`, [chamado_id]);

                    // Buscar profissional ID
                    const chamadoRes = await pool.query(`SELECT profissional_id FROM chamados_express WHERE id = $1`, [chamado_id]);
                    
                    // Notificar Profissional
                    const io = req.app.get('io');
                    const profissionaisConectados = req.app.get('profissionaisConectados');
                    if (io && profissionaisConectados) {
                        const socketId = profissionaisConectados.get(chamadoRes.rows[0].profissional_id);
                        if (socketId) {
                            io.to(socketId).emit('pagamento_confirmado', {
                                chamado_id,
                                valor: updateRes.rows[0].valor_profissional
                            });
                        }
                    }
                }
            }
        }
        return res.status(200).send('OK');
    } catch (e) {
        logger.error(`[WEBHOOK] Erro: ${e.message}`);
        return res.status(500).send('Erro no webhook');
    }
};

module.exports = {
    estimarPreco,
    processarPagamento,
    webhookMercadoPago
};
