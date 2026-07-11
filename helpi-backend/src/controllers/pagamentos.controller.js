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

        const clienteQuery = await pool.query(
            `SELECT email, cpf FROM clientes WHERE id = $1`,
            [cliente_id]
        );
        
        if (clienteQuery.rows.length === 0) {
            return res.status(404).json({ erro: 'Cliente não encontrado.' });
        }
        const clienteData = clienteQuery.rows[0];

        // SEGURANÇA V7: Rejeita pagamento se o cliente não tem CPF válido cadastrado
        if (!clienteData.cpf) {
            return res.status(400).json({ erro: 'CPF não cadastrado. Atualize seu perfil antes de realizar pagamentos.' });
        }
        const cpfLimpo = clienteData.cpf.replace(/\D/g, '');
        if (cpfLimpo.length !== 11) {
            return res.status(400).json({ erro: 'CPF inválido no cadastro. Atualize seu perfil.' });
        }

        const method_id = payment_method_id || 'pix';
        
        // Separa o nome em first_name e last_name para evitar que o PIX caia em modo assíncrono na API de Orders
        const nomeCompleto = (clienteData.nome || payer?.first_name || 'Cliente').trim().split(' ');
        const firstName = nomeCompleto[0];
        const lastName = nomeCompleto.length > 1 ? nomeCompleto.slice(1).join(' ') : 'Helpi';

        const paymentBody = {
            type: 'online',
            processing_mode: 'automatic',
            external_reference: chamado_id,
            total_amount: valorTotal.toFixed(2),
            description: description || `Serviço Helpi - Chamado ${chamado_id.split('-')[0]}`,
            payer: {
                email: clienteData.email || payer?.email,
                first_name: firstName,
                last_name: lastName,
                identification: {
                    type: 'CPF',
                    number: cpfLimpo.length === 11 ? cpfLimpo : '00000000000'
                }
            },
            transactions: {
                payments: [
                    {
                        amount: valorTotal.toFixed(2),
                        payment_method: {
                            id: method_id
                        }
                    }
                ]
            }
        };

        // Adiciona campos extra dependendo do meio de pagamento
        if (method_id === 'pix') {
            paymentBody.transactions.payments[0].payment_method.type = 'bank_transfer';
        }

        if (token) {
            paymentBody.transactions.payments[0].payment_method.type = 'credit_card';
            paymentBody.transactions.payments[0].payment_method.token = token;
        }
        if (installments) {
            paymentBody.transactions.payments[0].payment_method.installments = installments;
        }

        const requestOptions = {
            body: paymentBody,
            requestOptions: {
                idempotencyKey: crypto.randomUUID()
            }
        };

        const { order } = require('../config/mercadopago');
        const mpResponse = await order.create(requestOptions);

        const paymentData = mpResponse.transactions?.payments?.[0];
        if (!paymentData) {
            throw new Error('Mercado Pago não retornou os dados do pagamento dentro da order.');
        }

        // 3. Guardar Pagamento na BD
        await pool.query(
            `INSERT INTO pagamentos (chamado_id, mp_payment_id, valor_total, valor_profissional, valor_plataforma, status, metodo_pagamento)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [
                chamado_id, 
                paymentData.id.toString(), 
                valorTotal, 
                valorProfissional, 
                valorPlataforma, 
                paymentData.status || mpResponse.status, // 'approved', 'in_process', 'rejected', 'action_required'
                method_id
            ]
        );

        // Atualizar status do chamado se aprovado imediatamente
        if (paymentData.status === 'approved' || mpResponse.status === 'approved') {
            await pool.query(`UPDATE chamados_express SET pagamento_status = 'pago' WHERE id = $1`, [chamado_id]);
            
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
            status: paymentData.status || mpResponse.status,
            id: paymentData.id,
            order_id: mpResponse.id,
            qr_code: paymentData.payment_method?.qr_code || paymentData.qr_code,
            qr_code_base64: paymentData.payment_method?.qr_code_base64 || paymentData.qr_code_base64
        });
        
    } catch (erro) {
        logger.error(`[PAGAMENTO] Erro: ${erro.message}`);
        
        // Tratamento específico para erro do Mercado Pago (Credenciais de Produção não autorizadas/validadas)
        if (erro.message && erro.message.includes('Unauthorized use of live credentials')) {
            return res.status(400).json({ 
                erro: 'A sua conta do Mercado Pago ainda não está autorizada para receber pagamentos reais (produção). Utilize as credenciais de Teste (TEST-...) ou valide a sua conta no painel do Mercado Pago.' 
            });
        }
        
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
                     WHERE mp_payment_id = $1 RETURNING chamado_id, valor_profissional, valor_total`,
                    [paymentId.toString()]
                );
                
                if (updateRes.rows.length > 0) {
                    const chamado_id = updateRes.rows[0].chamado_id;
                    await pool.query(`UPDATE chamados_express SET pagamento_status = 'pago' WHERE id = $1`, [chamado_id]);
                    
                    logger.info(`[FINANÇAS] 💰 Dinheiro na conta! Chamado #${chamado_id} pago com sucesso.`);

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
            } else {
                logger.info(`[WEBHOOK] Pagamento ${paymentId} atualizado para status: ${mpPayment.status}`);
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
