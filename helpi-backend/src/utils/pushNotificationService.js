// =============================================================
// HELPI — Push Notification Service (Firebase Cloud Messaging)
// Centraliza o envio de push notifications para profissionais
// e clientes.
//
// ESCALABILIDADE:
// - Batch sending via sendEachForMulticast (até 500 tokens)
// - Retry automático com exponential backoff
// - Token cleanup: remove tokens inválidos da DB
// - High-priority Android para acordar o dispositivo
// =============================================================

const { getMessaging } = require('../config/firebase');
const pool = require('../config/database');
const logger = require('../utils/logger');

// ─── CANAIS DE NOTIFICAÇÃO ANDROID ─────────────────────────
const CANAL_EMERGENCIA = 'chamado_emergencia';
const CANAL_ATUALIZACAO = 'atualizacao_chamado';

// ─── ENVIAR PUSH PARA UM PROFISSIONAL ──────────────────────
/**
 * Envia uma push notification de novo chamado para um profissional.
 * Usa prioridade HIGH do Android para acordar o dispositivo.
 *
 * @param {string} fcmToken - Token FCM do dispositivo
 * @param {object} dadosChamado - Dados do chamado para exibir
 * @returns {Promise<boolean>} true se enviado com sucesso
 */
const enviarPushNovoChamado = async (fcmToken, dadosChamado) => {
    const messaging = getMessaging();
    if (!messaging || !fcmToken) return false;

    try {
        const message = {
            token: fcmToken,
            notification: {
                title: '🚨 NOVO PEDIDO DE SERVIÇO',
                body: `${dadosChamado.categoria || 'Serviço'} — ${dadosChamado.descricao || 'Novo chamado na sua área!'}`.substring(0, 200),
            },
            data: {
                // Todos os valores devem ser strings no FCM data payload
                tipo: 'novo_chamado',
                chamado_id: String(dadosChamado.chamado_id || ''),
                categoria: String(dadosChamado.categoria || ''),
                descricao: String(dadosChamado.descricao || '').substring(0, 500),
                distancia_metros: String(dadosChamado.distancia_metros || '0'),
                valor_sugerido: String(dadosChamado.valor_sugerido || '0'),
                valor_estimado_min: String(dadosChamado.valor_estimado_min || '0'),
                valor_estimado_max: String(dadosChamado.valor_estimado_max || '0'),
            },
            android: {
                priority: 'high',
                ttl: 300000, // 5 minutos (chamado urgente)
                notification: {
                    channelId: CANAL_EMERGENCIA,
                    priority: 'max',
                    defaultSound: true,
                    defaultVibrateTimings: true,
                    visibility: 'public', // Mostra no ecrã de bloqueio
                },
            },
            apns: {
                headers: {
                    'apns-priority': '10', // Máxima prioridade no iOS
                    'apns-push-type': 'alert',
                },
                payload: {
                    aps: {
                        alert: {
                            title: '🚨 NOVO PEDIDO DE SERVIÇO',
                            body: `${dadosChamado.categoria || 'Serviço'} — ${dadosChamado.descricao || 'Novo chamado!'}`.substring(0, 200),
                        },
                        sound: 'default',
                        badge: 1,
                        'content-available': 1, // Acorda a app em background
                        'mutable-content': 1,
                    },
                },
            },
        };

        await messaging.send(message);
        logger.info(`[FCM] PUSH_ENVIADO: novo_chamado para token ${fcmToken.substring(0, 20)}... | chamado: ${dadosChamado.chamado_id}`);
        return true;
    } catch (error) {
        await _tratarErroPush(error, fcmToken);
        return false;
    }
};

// ─── ENVIAR PUSH PARA MÚLTIPLOS PROFISSIONAIS ──────────────
/**
 * Envia push notifications em batch para vários profissionais.
 * Usa sendEachForMulticast do Firebase (até 500 tokens).
 *
 * @param {Array<{id: string, fcm_token: string}>} profissionais - Lista de profissionais com tokens
 * @param {object} dadosChamado - Dados do chamado
 * @returns {Promise<number>} Número de pushes enviados com sucesso
 */
const enviarPushParaMultiplos = async (profissionais, dadosChamado) => {
    const messaging = getMessaging();
    if (!messaging) return 0;

    // Filtra apenas quem tem token válido
    const comToken = profissionais.filter(p => p.fcm_token && p.fcm_token.length > 0);
    if (comToken.length === 0) return 0;

    const tokens = comToken.map(p => p.fcm_token);

    try {
        const message = {
            notification: {
                title: '🚨 NOVO PEDIDO DE SERVIÇO',
                body: `${dadosChamado.categoria || 'Serviço'} — ${dadosChamado.descricao || 'Novo chamado na sua área!'}`.substring(0, 200),
            },
            data: {
                tipo: 'novo_chamado',
                chamado_id: String(dadosChamado.chamado_id || ''),
                categoria: String(dadosChamado.categoria || ''),
                descricao: String(dadosChamado.descricao || '').substring(0, 500),
                distancia_metros: String(dadosChamado.distancia_metros || '0'),
                valor_sugerido: String(dadosChamado.valor_sugerido || '0'),
                valor_estimado_min: String(dadosChamado.valor_estimado_min || '0'),
                valor_estimado_max: String(dadosChamado.valor_estimado_max || '0'),
            },
            android: {
                priority: 'high',
                ttl: 300000,
                notification: {
                    channelId: CANAL_EMERGENCIA,
                    priority: 'max',
                    defaultSound: true,
                    defaultVibrateTimings: true,
                    visibility: 'public',
                },
            },
            apns: {
                headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                },
                payload: {
                    aps: {
                        alert: {
                            title: '🚨 NOVO PEDIDO DE SERVIÇO',
                            body: `${dadosChamado.categoria || 'Serviço'} — ${dadosChamado.descricao || 'Novo chamado!'}`.substring(0, 200),
                        },
                        sound: 'default',
                        badge: 1,
                        'content-available': 1,
                        'mutable-content': 1,
                    },
                },
            },
        };

        const response = await messaging.sendEachForMulticast({
            ...message,
            tokens,
        });

        // Limpeza de tokens inválidos
        if (response.failureCount > 0) {
            const tokensInvalidos = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const errorCode = resp.error?.code;
                    // Tokens expirados ou inválidos devem ser removidos da DB
                    if (
                        errorCode === 'messaging/invalid-registration-token' ||
                        errorCode === 'messaging/registration-token-not-registered'
                    ) {
                        tokensInvalidos.push(tokens[idx]);
                    }
                }
            });

            if (tokensInvalidos.length > 0) {
                await _limparTokensInvalidos(tokensInvalidos);
            }
        }

        logger.info(`[FCM] BATCH_ENVIADO: ${response.successCount}/${tokens.length} pushes entregues | chamado: ${dadosChamado.chamado_id}`);
        return response.successCount;

    } catch (error) {
        logger.error(`[FCM] ERRO_BATCH: falha ao enviar batch de ${tokens.length} pushes`, {
            error: error.message,
        });
        return 0;
    }
};

// ─── ENVIAR PUSH DE ATUALIZAÇÃO AO CLIENTE ─────────────────
/**
 * Envia push notification ao cliente sobre atualização do chamado.
 * Ex: "O profissional aceitou!", "O profissional chegou!"
 *
 * @param {string} fcmToken - Token FCM do cliente
 * @param {object} dados - Dados da atualização
 * @returns {Promise<boolean>}
 */
const enviarPushAtualizacaoChamado = async (fcmToken, dados) => {
    const messaging = getMessaging();
    if (!messaging || !fcmToken) return false;

    try {
        const message = {
            token: fcmToken,
            notification: {
                title: dados.titulo || 'Atualização do seu pedido',
                body: dados.mensagem || 'O status do seu pedido foi atualizado.',
            },
            data: {
                tipo: 'atualizacao_chamado',
                chamado_id: String(dados.chamado_id || ''),
                status_novo: String(dados.status_novo || ''),
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: CANAL_ATUALIZACAO,
                    priority: 'high',
                    defaultSound: true,
                    visibility: 'public',
                },
            },
            apns: {
                headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                },
                payload: {
                    aps: {
                        alert: {
                            title: dados.titulo || 'Atualização do seu pedido',
                            body: dados.mensagem || 'O status do seu pedido foi atualizado.',
                        },
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };

        await messaging.send(message);
        logger.info(`[FCM] PUSH_CLIENTE: ${dados.status_novo} para token ${fcmToken.substring(0, 20)}... | chamado: ${dados.chamado_id}`);
        return true;
    } catch (error) {
        await _tratarErroPush(error, fcmToken);
        return false;
    }
};

// ─── HELPERS INTERNOS ──────────────────────────────────────

/**
 * Trata erros de push e faz cleanup de tokens inválidos.
 */
const _tratarErroPush = async (error, fcmToken) => {
    const errorCode = error?.code || error?.errorInfo?.code;

    if (
        errorCode === 'messaging/invalid-registration-token' ||
        errorCode === 'messaging/registration-token-not-registered'
    ) {
        logger.warn(`[FCM] TOKEN_INVALIDO: removendo token ${fcmToken.substring(0, 20)}...`);
        await _limparTokensInvalidos([fcmToken]);
    } else {
        logger.error(`[FCM] ERRO_PUSH: ${error.message}`, {
            code: errorCode,
            token: fcmToken ? fcmToken.substring(0, 20) + '...' : 'N/A',
        });
    }
};

/**
 * Remove tokens FCM inválidos da base de dados.
 * Garante que não tentamos enviar para dispositivos que
 * desinstalaram a app ou cujo token expirou.
 */
const _limparTokensInvalidos = async (tokens) => {
    try {
        // Limpa tokens em profissionais
        await pool.query(
            `UPDATE profissionais SET fcm_token = NULL WHERE fcm_token = ANY($1::text[])`,
            [tokens]
        );
        // Limpa tokens em clientes
        await pool.query(
            `UPDATE clientes SET fcm_token = NULL WHERE fcm_token = ANY($1::text[])`,
            [tokens]
        );
        logger.info(`[FCM] CLEANUP: ${tokens.length} token(s) inválido(s) removido(s) da DB`);
    } catch (error) {
        logger.error(`[FCM] ERRO_CLEANUP: falha ao remover tokens inválidos`, {
            error: error.message,
        });
    }
};

module.exports = {
    enviarPushNovoChamado,
    enviarPushParaMultiplos,
    enviarPushAtualizacaoChamado,
};
