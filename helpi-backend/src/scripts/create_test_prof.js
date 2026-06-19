const pool = require('../config/database');
const bcrypt = require('bcrypt');

const createProfissional = async () => {
    try {
        const senhaPlana = 'eletricista123';
        const senhaHash = await bcrypt.hash(senhaPlana, 10);
        
        // Verifica se já existe
        const existe = await pool.query('SELECT email FROM profissionais WHERE email = $1', ['ze.eletricista@helpi.com']);
        if (existe.rows.length > 0) {
            console.log('✅ O profissional já existe. Credenciais: ze.eletricista@helpi.com / eletricista123');
            process.exit(0);
        }

        const query = `
            INSERT INTO profissionais (nome, cpf_cnpj, email, senha, telefone, categoria, status)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id, nome, email;
        `;
        const values = [
            'José Eletricista', 
            '11122233344', 
            'ze.eletricista@helpi.com', 
            senhaHash, 
            '999999999', 
            'eletricista',
            'aprovado' // Precisa estar aprovado para o login passar
        ];

        const res = await pool.query(query, values);
        console.log('✅ Profissional criado com sucesso!');
        console.log('--- CREDENCIAIS ---');
        console.log('Email:', res.rows[0].email);
        console.log('Senha:', senhaPlana);
        console.log('-------------------');
    } catch (err) {
        console.error('❌ Erro ao criar profissional:', err);
    } finally {
        pool.end();
    }
};

createProfissional();
