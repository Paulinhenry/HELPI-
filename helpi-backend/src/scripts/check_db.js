const pool = require('../config/database');

const run = async () => {
    try {
        const chamados = await pool.query('SELECT id, latitude_destino, longitude_destino FROM chamados_express ORDER BY criado_em DESC LIMIT 1');
        const chamado = chamados.rows[0];
        console.log('Chamado Destino:', chamado);

        const profs = await pool.query('SELECT id, is_online, categoria, ST_AsText(coordenadas) as coords FROM profissionais WHERE is_online = true');
        console.log('Profissionais Online:', profs.rows);

        // Execute the exact ST_Distance query
        const query = `
            SELECT id, nome, categoria,
                ST_Distance(
                    coordenadas,
                    ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography
                ) / 1000 AS distancia_km
            FROM profissionais
            WHERE is_online = true
              AND LOWER(categoria) = LOWER($3)
              AND status = 'aprovado'
              AND coordenadas IS NOT NULL
        `;
        const params = [
            chamado.latitude_destino,
            chamado.longitude_destino,
            'Eletricista'
        ];
        const res = await pool.query(query, params);
        console.log('Query Match:', res.rows);
    } catch (e) {
        console.error(e);
    } finally {
        pool.end();
    }
};

run();
