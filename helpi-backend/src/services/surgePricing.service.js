const pool = require('../config/database');
const logger = require('./logger.service'); // Assuming logger.service exists, otherwise I should use console.log or standard logger

/**
 * Motor de Preço Dinâmico (Surge Pricing) e Mapa de Calor
 */
class SurgePricingService {
    constructor() {
        this.RAIO_CLUSTER_GRAUS = 0.027; // Aprox 3km (1 grau ~= 111.32km na linha do Equador)
        this.MIN_CHAMADOS_CLUSTER = 1;
        this.MULTIPLICADOR_MAX = 2.5;
        this.RAIO_PROFISSIONAL_GRAUS = 0.027; // Raio para buscar profissionais na área
    }

    /**
     * Obtém as Zonas Quentes atuais agrupando os chamados ativos.
     * @returns {Promise<Array>} Array de zonas quentes { centro_lat, centro_lng, raio_metros, multiplicador, total_chamados }
     */
    async obterZonasQuentes() {
        try {
            // Query 1: Agrupar chamados usando ST_ClusterDBSCAN
            // Filtra chamados em busca de profissional nos últimos 30 min (para evitar chamados fantasmas)
            const queryClusters = `
                WITH chamados_geoms AS (
                    SELECT 
                        id,
                        ST_SetSRID(ST_MakePoint(longitude_destino, latitude_destino), 4326) AS geom
                    FROM chamados_express
                    WHERE status = 'procurando_profissional'
                      AND criado_em >= NOW() - INTERVAL '30 minutes'
                ),
                clusters AS (
                    SELECT 
                        ST_ClusterDBSCAN(geom, eps := $1, minpoints := $2) OVER() AS cluster_id,
                        geom
                    FROM chamados_geoms
                ),
                centros AS (
                    SELECT 
                        cluster_id,
                        ST_Centroid(ST_Collect(geom)) AS centro_geom,
                        COUNT(*) AS total_chamados
                    FROM clusters
                    WHERE cluster_id IS NOT NULL
                    GROUP BY cluster_id
                )
                SELECT 
                    cluster_id,
                    ST_Y(centro_geom) AS centro_lat,
                    ST_X(centro_geom) AS centro_lng,
                    total_chamados
                FROM centros;
            `;

            const resultClusters = await pool.query(queryClusters, [this.RAIO_CLUSTER_GRAUS, this.MIN_CHAMADOS_CLUSTER]);
            const zonas = [];

            for (const row of resultClusters.rows) {
                const { centro_lat, centro_lng, total_chamados } = row;

                // Query 2: Contar profissionais online próximos ao centro deste cluster
                const queryProfissionais = `
                    SELECT COUNT(*) as total_profissionais
                    FROM profissionais
                    WHERE is_online = true
                      AND latitude_atual IS NOT NULL
                      AND longitude_atual IS NOT NULL
                      AND ST_DWithin(
                          ST_SetSRID(ST_MakePoint(longitude_atual, latitude_atual), 4326)::geography,
                          ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
                          3000 -- 3km em metros (tipo geography usa metros)
                      )
                `;
                const resultProfissionais = await pool.query(queryProfissionais, [centro_lng, centro_lat]);
                const totalProfissionais = parseInt(resultProfissionais.rows[0].total_profissionais, 10);

                // Calcular multiplicador (Demand vs Supply)
                let multiplicador = 1.0;
                
                // Exemplo de lógica: se há mais chamados que profissionais
                if (total_chamados > totalProfissionais) {
                    // Cálculo: (Chamados / (Profissionais + 1))
                    // O +1 evita divisão por zero
                    let ratio = total_chamados / (totalProfissionais + 1);
                    
                    if (ratio > 1) {
                        multiplicador = 1.0 + (ratio * 0.2); // +20% por ponto de ratio
                    }
                }

                // Teto do multiplicador
                if (multiplicador > this.MULTIPLICADOR_MAX) {
                    multiplicador = this.MULTIPLICADOR_MAX;
                }

                zonas.push({
                    centro_lat,
                    centro_lng,
                    raio_metros: 3000,
                    multiplicador: parseFloat(multiplicador.toFixed(2)),
                    total_chamados,
                    total_profissionais: totalProfissionais
                });
            }

            return zonas;
        } catch (error) {
            console.error('[SurgePricing] Erro ao obter zonas quentes: ' + error.message);
            return [];
        }
    }

    /**
     * Calcula o multiplicador exato para uma coordenada (ex: cliente pedindo chamado)
     * @param {Number} lat Latitude do cliente
     * @param {Number} lng Longitude do cliente
     * @returns {Promise<Number>} Multiplicador de 1.0 a 2.5
     */
    async calcularMultiplicadorParaLocal(lat, lng) {
        if (!lat || !lng) return 1.0;

        try {
            const zonas = await this.obterZonasQuentes();
            
            let maiorMultiplicador = 1.0;

            for (const zona of zonas) {
                const queryDist = `
                    SELECT ST_Distance(
                        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
                        ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography
                    ) AS dist_metros
                `;
                const result = await pool.query(queryDist, [lng, lat, zona.centro_lng, zona.centro_lat]);
                const distMetros = parseFloat(result.rows[0].dist_metros);

                if (distMetros <= zona.raio_metros) {
                    if (zona.multiplicador > maiorMultiplicador) {
                        maiorMultiplicador = zona.multiplicador;
                    }
                }
            }

            return maiorMultiplicador;
        } catch (error) {
            console.error('[SurgePricing] Erro ao calcular multiplicador local: ' + error.message);
            return 1.0;
        }
    }
}

module.exports = new SurgePricingService();
