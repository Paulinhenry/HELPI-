const winston = require('winston');

const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        // Guarda erros num ficheiro específico
        new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
        // Guarda tudo num ficheiro geral
        new winston.transports.File({ filename: 'logs/combined.log' }),
    ],
});

// Se não estivermos em produção, loga também na consola para facilitar o desenvolvimento
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.simple(),
    }));
}

module.exports = logger;