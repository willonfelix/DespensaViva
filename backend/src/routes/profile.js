const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');

const router = express.Router();
router.use(requireAuth);

// Dados do perfil do usuário (nunca expõe a API key em texto plano)
router.get('/', async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT id, email, name, created_at,
              gemini_api_key IS NOT NULL AND gemini_api_key <> '' AS has_gemini_key
       FROM users WHERE id = $1`,
      [req.userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }
    return res.json({ user: result.rows[0] });
  } catch (err) {
    return next(err);
  }
});

// Troca de senha (valida senha atual)
router.put('/password', async (req, res, next) => {
  try {
    const { current_password, new_password } = req.body || {};

    if (!current_password || !new_password) {
      return res.status(400).json({ error: 'Informe a senha atual e a nova senha.' });
    }
    if (String(new_password).length < 6) {
      return res.status(400).json({ error: 'A nova senha deve ter no mínimo 6 caracteres.' });
    }

    const result = await db.query(
      'SELECT password_hash FROM users WHERE id = $1',
      [req.userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }

    const valid = await bcrypt.compare(String(current_password), result.rows[0].password_hash);
    if (!valid) {
      return res.status(400).json({ error: 'Senha atual incorreta.' });
    }

    const passwordHash = await bcrypt.hash(String(new_password), 10);
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [
      passwordHash,
      req.userId,
    ]);
    return res.json({ message: 'Senha atualizada com sucesso.' });
  } catch (err) {
    return next(err);
  }
});

// Salva/atualiza/remove a API Key do Gemini (enviar "" remove)
router.put('/gemini-key', async (req, res, next) => {
  try {
    const { gemini_key } = req.body || {};

    if (gemini_key === undefined || gemini_key === null) {
      return res.status(400).json({ error: 'Informe a chave do Gemini.' });
    }

    const key = String(gemini_key).trim();
    await db.query('UPDATE users SET gemini_api_key = $1 WHERE id = $2', [
      key === '' ? null : key,
      req.userId,
    ]);
    return res.json({
      message: key === '' ? 'Chave removida.' : 'Chave salva com sucesso.',
      has_gemini_key: key !== '',
    });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
