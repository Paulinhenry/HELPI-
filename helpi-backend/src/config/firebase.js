// =============================================================
// HELPI — Configuração Firebase Admin SDK
// Inicializa o Firebase a partir da Service Account Key
// armazenada na variável de ambiente FIREBASE_SERVICE_ACCOUNT_JSON.
//
// ESCALABILIDADE:
// - Env var com JSON inline (funciona em Render, Railway, Docker, K8s)
// - Sem ficheiros no disco (seguro para deploys efémeros)
// - Singleton: importa sempre a mesma instância
// =============================================================

const admin = require('firebase-admin');
const logger = require('../utils/logger');

let firebaseApp = null;

/**
 * Inicializa o Firebase Admin SDK a partir da env var.
 * Chamado uma vez no arranque do servidor.
 * Se a env var não existir, o servidor continua a funcionar
 * sem push notifications (graceful degradation).
 */
const inicializarFirebase = () => {
    if (firebaseApp) return firebaseApp;

    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

    if (!serviceAccountJson) {
        logger.warn('[FIREBASE] FIREBASE_SERVICE_ACCOUNT_JSON não definida. Push notifications desativadas.');
        return null;
    }

    try {
        const serviceAccount = JSON.parse(serviceAccountJson);

        firebaseApp = admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
        });

        logger.info('[FIREBASE] Firebase Admin SDK inicializado com sucesso.');
        return firebaseApp;
    } catch (error) {
        logger.error('[FIREBASE] Erro ao inicializar Firebase Admin SDK:', {
            error: error.message,
            stack: error.stack,
        });
        return null;
    }
};

/**
 * Retorna a instância do Firebase Messaging.
 * Retorna null se o Firebase não estiver inicializado.
 */
const getMessaging = () => {
    if (!firebaseApp) return null;
    return admin.messaging();
};

module.exports = { inicializarFirebase, getMessaging };
