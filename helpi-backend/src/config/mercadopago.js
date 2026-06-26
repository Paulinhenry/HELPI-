const { MercadoPagoConfig, Payment } = require('mercadopago');

// Inicializa o cliente com o Access Token do .env
const client = new MercadoPagoConfig({ accessToken: process.env.MP_ACCESS_TOKEN });

const payment = new Payment(client);

module.exports = {
    client,
    payment
};
