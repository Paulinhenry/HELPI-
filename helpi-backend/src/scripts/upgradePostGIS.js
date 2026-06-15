const pool = require('../config/database');

const ativarPostGIS = async () => {
    const cliente = await pool.connect();
    try {
        console.log('🌍 A iniciar o upgrade para PostGIS (Motor Espacial)...');

        // 1. Ativar a extensão na Neon
        await cliente.query('CREATE EXTENSION IF NOT EXISTS postgis;');
        console.log('✅ Extensão PostGIS ativada com sucesso!');

        // 2. Adicionar a coluna de Geografia verdadeira
        await cliente.query(`
            ALTER TABLE profissionais 
            ADD COLUMN IF NOT EXISTS coordenadas GEOGRAPHY(Point, 4326);
        `);

        // 3. Criar a Função e o Gatilho (O segredo da automatização)
        // Sempre que alguém inserir ou atualizar a latitude/longitude, a base de dados
        // converte isso automaticamente num ponto no globo terrestre.
        await cliente.query(`
            CREATE OR REPLACE FUNCTION atualiza_coordenadas_profissionais()
            RETURNS TRIGGER AS $$
            BEGIN
                IF NEW.latitude_atual IS NOT NULL AND NEW.longitude_atual IS NOT NULL THEN
                    -- ATENÇÃO: No mundo GIS, é sempre (Longitude, Latitude)
                    NEW.coordenadas := ST_SetSRID(ST_MakePoint(NEW.longitude_atual, NEW.latitude_atual), 4326);
                END IF;
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        `);

        await cliente.query(`
            DROP TRIGGER IF EXISTS prof_coordenadas_trigger ON profissionais;
            CREATE TRIGGER prof_coordenadas_trigger
            BEFORE INSERT OR UPDATE OF latitude_atual, longitude_atual
            ON profissionais
            FOR EACH ROW EXECUTE FUNCTION atualiza_coordenadas_profissionais();
        `);

        // 4. Migrar os dados de teste que já estão na base de dados
        await cliente.query(`
            UPDATE profissionais 
            SET coordenadas = ST_SetSRID(ST_MakePoint(longitude_atual, latitude_atual), 4326)
            WHERE latitude_atual IS NOT NULL;
        `);

        // 5. O MAIS IMPORTANTE: Criar o Índice Espacial (GiST)
        await cliente.query(`
            CREATE INDEX IF NOT EXISTS prof_coordenadas_idx 
            ON profissionais USING GIST (coordenadas);
        `);

        console.log('✅ Colunas geográficas, Gatilhos e Índice GiST criados!');
        console.log('🚀 A tua API é agora oficialmente uma máquina de localização em tempo real!');

    } catch (erro) {
        console.error('❌ Erro crítico ao atualizar para PostGIS:', erro);
    } finally {
        cliente.release();
        pool.end();
    }
};

ativarPostGIS();