// =============================================================
// HELPI - Controlador de Profissionais
// Gerencia registo, listagem e perfil de profissionais.
//
// ESCALABILIDADE:
// - Paginação cursor-based (sem OFFSET lento)
// - Soft-delete (nunca apaga dados)
// =============================================================

const pool = require('../config/database');
const bcrypt = require('bcrypt');
const logger = require('../utils/logger');

const SALT_ROUNDS = 12;

// ─── LISTAR PROFISSIONAIS (COM PAGINAÇÃO) ───────────────────
const listarProfissionais = async (req, res, next) => {
    try {
        const { categoria, cursor, cursor_id, limit = 20 } = req.query;
        const limitNum = Math.min(parseInt(limit, 10) || 20, 50); // Max 50 por página

        let query = `
            SELECT id, nome, categoria, biografia, taxa_visita, nota_media as avaliacao
            FROM profissionais
            WHERE status = $1 AND deletado_em IS NULL
        `;
        const valores = ['aprovado'];
        let paramIndex = 2;

        if (categoria) {
            query += ` AND categoria = $${paramIndex}`;
            valores.push(categoria);
            paramIndex++;
        }

        // Paginação com cursor composto (nota_media + id) para evitar duplicatas
        if (cursor && cursor_id) {
            query += ` AND (nota_media, id) < ($${paramIndex}, $${paramIndex + 1})`;
            valores.push(cursor, cursor_id);
            paramIndex += 2;
        }

        query += ` ORDER BY nota_media DESC, id DESC LIMIT $${paramIndex}`;
        valores.push(limitNum + 1);

        const resultado = await pool.query(query, valores);
        const hasMore = resultado.rows.length > limitNum;
        const profissionais = hasMore ? resultado.rows.slice(0, limitNum) : resultado.rows;
        const ultimo = profissionais.length > 0 ? profissionais[profissionais.length - 1] : null;

        res.json({
            profissionais,
            paginacao: {
                total_retornado: profissionais.length,
                proximo_cursor: hasMore && ultimo ? ultimo.avaliacao : null,
                proximo_cursor_id: hasMore && ultimo ? ultimo.id : null,
                tem_mais: hasMore
            }
        });
    } catch (erro) {
        next(erro);
    }
};

// ─── VER PROFISSIONAL ───────────────────────────────────────
const verProfissional = async (req, res, next) => {
    try {
        const { id } = req.params;
        const resultado = await pool.query(
            `SELECT id, nome, categoria, biografia, taxa_visita, nota_media as avaliacao, criado_em
             FROM profissionais
             WHERE id = $1 AND deletado_em IS NULL`,
            [id]
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ erro: "Profissional não encontrado." });
        }

        // Busca avaliações do profissional
        const avaliacoes = await pool.query(
            `SELECT nota, comentario, criado_em
             FROM avaliacoes
             WHERE profissional_id = $1
             ORDER BY criado_em DESC
             LIMIT 10`,
            [id]
        );

        res.json({
            ...resultado.rows[0],
            ultimas_avaliacoes: avaliacoes.rows
        });
    } catch (erro) {
        next(erro);
    }
};

// ─── REGISTAR PROFISSIONAL ──────────────────────────────────
const registarProfissional = async (req, res, next) => {
    try {
        const { nome, cpf_cnpj, email, senha, telefone, categoria, biografia } = req.body;
        const senhaHash = await bcrypt.hash(senha, SALT_ROUNDS);

        const novoProfissional = await pool.query(
            `INSERT INTO profissionais
            (nome, cpf_cnpj, email, senha, telefone, categoria, biografia)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id, nome, categoria, status, criado_em`,
            [nome, cpf_cnpj, email.toLowerCase().trim(), senhaHash, telefone, categoria, biografia]
        );

        logger.info(`[PROFISSIONAL] REGISTADO: profissional ${novoProfissional.rows[0].id} | categoria: ${categoria} | status: aguardando_aprovacao`);

        res.status(201).json({
            mensagem: "Profissional registado com sucesso! Aguardando aprovação.",
            profissional: novoProfissional.rows[0]
        });
    } catch (erro) {
        next(erro);
    }
};

// ─── ATUALIZAR PERFIL DO PROFISSIONAL ───────────────────────
const atualizarPerfil = async (req, res, next) => {
    try {
        const profissional_id = req.usuario.id;
        const { nome, telefone, biografia, taxa_visita } = req.body;

        const campos = [];
        const valores = [];
        let paramIndex = 1;

        if (nome) { campos.push(`nome = $${paramIndex++}`); valores.push(nome.trim()); }
        if (telefone) { campos.push(`telefone = $${paramIndex++}`); valores.push(telefone); }
        if (biografia !== undefined) { campos.push(`biografia = $${paramIndex++}`); valores.push(biografia); }
        if (taxa_visita !== undefined) { campos.push(`taxa_visita = $${paramIndex++}`); valores.push(taxa_visita); }

        if (campos.length === 0) {
            return res.status(400).json({ erro: 'Nenhum campo para atualizar.' });
        }

        campos.push(`atualizado_em = CURRENT_TIMESTAMP`);
        valores.push(profissional_id);

        const resultado = await pool.query(
            `UPDATE profissionais
             SET ${campos.join(', ')}
             WHERE id = $${paramIndex} AND deletado_em IS NULL
             RETURNING id, nome, categoria, biografia, taxa_visita, telefone`,
            valores
        );

        if (resultado.rows.length === 0) {
            return res.status(404).json({ erro: 'Profissional não encontrado.' });
        }

        logger.info(`[PROFISSIONAL] PERFIL_ATUALIZADO: profissional ${profissional_id} | campos: ${campos.filter(c => !c.startsWith('atualizado_em')).join(', ')}`);
        res.json({
            mensagem: 'Perfil atualizado com sucesso!',
            profissional: resultado.rows[0]
        });
    } catch (erro) {
        next(erro);
    }
};

module.exports = { listarProfissionais, verProfissional, registarProfissional, atualizarPerfil };