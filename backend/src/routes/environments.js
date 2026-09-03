const express = require('express');
const bcrypt = require('bcryptjs');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');

const router = express.Router();
router.use(requireAuth);

// Carrega os ambientes (e papel) do usuário logado, com os membros de cada um.
function loadEnvironments(userId) {
  return db.query(
    `SELECT e.id, e.name, e.owner_id AS "ownerId",
            em.role AS "myRole",
            (SELECT COUNT(*)::int FROM environment_members em2
               WHERE em2.environment_id = e.id) AS "memberCount"
     FROM environment_members em
     JOIN environments e ON e.id = em.environment_id
     WHERE em.user_id = $1
     ORDER BY e.created_at`,
    [userId]
  );
}

function loadMembers(environmentId) {
  return db.query(
    `SELECT em.user_id AS "userId", u.name, u.email, em.role
     FROM environment_members em
     JOIN users u ON u.id = em.user_id
     WHERE em.environment_id = $1
     ORDER BY em.role DESC, u.name`,
    [environmentId]
  );
}

// GET /api/environments
router.get('/', async (req, res, next) => {
  try {
    const result = await loadEnvironments(req.userId);
    return res.json({ environments: result.rows });
  } catch (err) {
    return next(err);
  }
});

// GET /api/environments/:id
router.get('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const envResult = await loadEnvironments(req.userId);
    const env = envResult.rows.find((e) => e.id === id);
    if (!env) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }
    const members = await loadMembers(id);
    return res.json({ environment: { ...env, members: members.rows } });
  } catch (err) {
    return next(err);
  }
});

// POST /api/environments
router.post('/', async (req, res, next) => {
  try {
    const { name } = req.body || {};
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Informe o nome do ambiente.' });
    }
    const trimmed = String(name).trim();

    const result = await db.transaction(async (client) => {
      const env = await client.query(
        'INSERT INTO environments (name, owner_id) VALUES ($1, $2) RETURNING id, name, owner_id AS "ownerId"',
        [trimmed, req.userId]
      );
      await client.query(
        'INSERT INTO environment_members (environment_id, user_id, role) VALUES ($1, $2, $3)',
        [env.rows[0].id, req.userId, 'owner']
      );
      return env.rows[0];
    });

    return res.status(201).json({ environment: { ...result, myRole: 'owner', memberCount: 1 } });
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/environments/:id
router.patch('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { name } = req.body || {};

    const member = await db.query(
      'SELECT role FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (member.rows.length === 0) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }
    if (member.rows[0].role !== 'owner') {
      return res.status(403).json({ error: 'Somente o dono pode renomear o ambiente.' });
    }
    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Informe o nome do ambiente.' });
    }

    const result = await db.query(
      'UPDATE environments SET name = $1 WHERE id = $2 RETURNING id, name',
      [String(name).trim(), id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Ambiente não encontrado.' });
    }
    return res.json({ environment: result.rows[0] });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/environments/:id
router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const member = await db.query(
      'SELECT role FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (member.rows.length === 0) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }
    if (member.rows[0].role !== 'owner') {
      return res.status(403).json({ error: 'Somente o dono pode excluir o ambiente.' });
    }
    await db.query('DELETE FROM environments WHERE id = $1', [id]);
    return res.status(204).end();
  } catch (err) {
    return next(err);
  }
});

// POST /api/environments/:id/members  — convida por e-mail
router.post('/:id/members', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { email } = req.body || {};
    if (!email || !String(email).trim()) {
      return res.status(400).json({ error: 'Informe o e-mail do usuário.' });
    }
    const normalized = String(email).trim().toLowerCase();

    const member = await db.query(
      'SELECT role FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (member.rows.length === 0) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }
    if (member.rows[0].role !== 'owner') {
      return res.status(403).json({ error: 'Somente o dono pode adicionar membros.' });
    }

    let invitedUser;
    await db.transaction(async (client) => {
      const existing = await client.query(
        'SELECT id FROM users WHERE email = $1',
        [normalized]
      );
      if (existing.rows.length > 0) {
        invitedUser = existing.rows[0];
      } else {
        const created = await client.query(
          `INSERT INTO users (email, name, password_hash)
           VALUES ($1, $2, $3)
           RETURNING id`,
          [normalized, normalized.split('@')[0], await bcrypt.hash(normalized, 10)]
        );
        invitedUser = created.rows[0];
      }

      await client.query(
        `INSERT INTO environment_members (environment_id, user_id, role)
         VALUES ($1, $2, 'member')
         ON CONFLICT (environment_id, user_id) DO NOTHING`,
        [id, invitedUser.id]
      );
    });

    const members = await loadMembers(id);
    return res.status(201).json({ members: members.rows });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/environments/:id/members/:userId
router.delete('/:id/members/:userId', async (req, res, next) => {
  try {
    const { id, userId } = req.params;
    const member = await db.query(
      'SELECT role FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (member.rows.length === 0) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }
    if (member.rows[0].role !== 'owner') {
      return res.status(403).json({ error: 'Somente o dono pode remover membros.' });
    }
    if (userId === req.userId) {
      return res.status(400).json({ error: 'O dono não pode remover a si mesmo.' });
    }
    await db.query(
      'DELETE FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [id, userId]
    );
    const members = await loadMembers(id);
    return res.json({ members: members.rows });
  } catch (err) {
    return next(err);
  }
});

// PUT /api/environments/:id/members/:userId  — muda o papel (owner <-> member)
router.put('/:id/members/:userId', async (req, res, next) => {
  try {
    const { id, userId } = req.params;
    const { role } = req.body || {};
    if (!role || !['owner', 'member'].includes(role)) {
      return res.status(400).json({ error: 'Papel inválido.' });
    }

    const member = await db.query(
      'SELECT role FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (member.rows.length === 0) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }
    if (member.rows[0].role !== 'owner') {
      return res.status(403).json({ error: 'Somente o dono pode alterar papéis.' });
    }

    await db.query(
      'UPDATE environment_members SET role = $1 WHERE environment_id = $2 AND user_id = $3',
      [role, id, userId]
    );
    if (role === 'owner') {
      await db.query(
        'UPDATE environments SET owner_id = $1 WHERE id = $2',
        [userId, id]
      );
      await db.query(
        'UPDATE environment_members SET role = $2 WHERE environment_id = $1 AND user_id = $3',
        [id, 'member', req.userId]
      );
    }

    const members = await loadMembers(id);
    return res.json({ members: members.rows });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
