const { MercadoPagoConfig, Payment, Order } = require('mercadopago');

if (!process.env.MP_ACCESS_TOKEN) {
    console.error('[ERRO FATAL] MP_ACCESS_TOKEN não está definido nas variáveis de ambiente!');
}

// Inicializa o cliente com o Access Token do .env
const client = new MercadoPagoConfig({ 
    accessToken: process.env.MP_ACCESS_TOKEN || 'MISSING_TOKEN',
    options: { timeout: 30000 }
});

const payment = new Payment(client);
const order = new Order(client);

module.exports = {
    client,
    payment,
    order
};
