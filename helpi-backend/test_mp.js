require('dotenv').config();
const { payment } = require('./src/config/mercadopago');
const crypto = require('crypto');

async function run() {
    try {
        const paymentBody = {
            transaction_amount: 10,
            description: 'Serviço Helpi - Chamado Teste',
            payment_method_id: 'pix',
            payer: {
                email: 'cliente@helpi.com',
                identification: { type: 'CPF', number: '12345678909' }
            }
        };

        const requestOptions = {
            body: paymentBody,
            requestOptions: {
                idempotencyKey: crypto.randomUUID()
            }
        };

        console.log("Enviando requisição ao Mercado Pago...");
        const response = await payment.create(requestOptions);
        console.log("Sucesso:", response.status);
    } catch (error) {
        console.error("Erro no Mercado Pago:", error.message);
        if (error.cause) {
            console.error("Causa do Erro:", error.cause);
        }
    }
}

run();
