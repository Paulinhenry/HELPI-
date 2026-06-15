// =============================================================
// HELPI - Configuração do Swagger / OpenAPI
// Gera a documentação interativa da API automaticamente.
// =============================================================

const swaggerJsdoc = require('swagger-jsdoc');
require('dotenv').config();

const PORT = process.env.PORT || 3000;

const options = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'Helpi API Documentation',
            version: '1.0.0',
            description: 'Documentação oficial da API do Helpi — Sistema On-Demand de Serviços.',
        },
        servers: [
            {
                url: `http://localhost:${PORT}`,
                description: 'Servidor Local',
            },
        ],
        // Esquema de segurança JWT para os endpoints protegidos
        components: {
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
                    description: 'Insira o token JWT obtido no login (sem o prefixo "Bearer")',
                },
            },
        },
    },
    // Aponta para os ficheiros de rotas onde está a documentação
    apis: ['./src/routes/*.js'],
};

const specs = swaggerJsdoc(options);

module.exports = specs;