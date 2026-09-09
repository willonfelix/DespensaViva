const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../config/data');
const { signToken } = require('../config/auth');
const requireAuth = require('../middlewares/auth');

const router = express.Router();

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

router.post('/register', async (req, res, next) => {
  try {
    const { email, password, name } = req.body || {};
    const normalized = normalizeEmail(email);

    if (!normalized || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalized)) {
      return res.status(400).json({ error: 'Informe um e-mail válido.' });
    }
    if (!password || String(password).length < 6) {
      return res.status(400).json({ error: 'A senha deve ter no mínimo 6 caracteres.' });
    }

    const existing = await db.query('SELECT id FROM users WHERE email = $1', [normalized]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Este e-mail já está cadastrado.' });
    }

    const passwordHash = await bcrypt.hash(String(password), 10);
    const result = await db.query(
      `INSERT INTO users (email, name, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, email, name, created_at`,
      [normalized, name ? String(name).trim() : null, passwordHash]
    );

    const user = result.rows[0];
    const token = signToken(user);
    return res.status(201).json({ token, user });
  } catch (err) {
    return next(err);
  }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {};
    const normalized = normalizeEmail(email);

    if (!normalized || !password) {
      return res.status(400).json({ error: 'Informe e-mail e senha.' });
    }

    const result = await db.query(
      'SELECT id, email, name, password_hash, created_at FROM users WHERE email = $1',
      [normalized]
    );
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'E-mail ou senha incorretos.' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(String(password), user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'E-mail ou senha incorretos.' });
    }

    delete user.password_hash;
    const token = signToken(user);
    await db.query(
      `INSERT INTO audit_logs (user_id, environment_id, action, entity, entity_id, details)
       VALUES ($1, NULL, 'auth.login', 'user', $2, $3)`,
      [user.id, String(user.id), JSON.stringify({ email: user.email })]
    );
    return res.json({ token, user });
  } catch (err) {
    return next(err);
  }
});

router.get('/me', requireAuth, async (req, res, next) => {
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

module.exports = router;