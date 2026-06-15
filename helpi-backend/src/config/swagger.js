const swaggerJsdoc = require('swagger-jsdoc');

const options = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'Helpi API Documentation',
            version: '1.0.0',
            description: 'Documentação oficial da API do Helpi - Sistema On-Demand',
        },
        servers: [
            {
                url: 'http://localhost:3000',
                description: 'Servidor Local',
            },
        ],
    },
    // Aponta para os teus ficheiros de rotas onde escreveremos a documentação
    apis: ['./src/routes/*.js'], 
};

const specs = swaggerJsdoc(options);

module.exports = specs;