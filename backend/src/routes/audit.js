const express = require('express');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');

const router = express.Router();
router.use(requireAuth);

// GET /api/audit — últimos registros de auditoria do usuário
router.get('/', async (req, res, next) => {
  try {
    const params = [req.userId];
    let filter = ' WHERE a.user_id = $1';
    if (req.query.environment_id) {
      params.push(req.query.environment_id);
      filter += ` AND a.environment_id = $${params.length}`;
    }
    const limit = Math.min(Number(req.query.limit) || 50, 200);

    const result = await db.query(
      `SELECT a.id, a.action, a.entity, a.entity_id AS "entityId",
              a.details, a.created_at AS "createdAt",
              e.name AS environment
       FROM audit_logs a
       LEFT JOIN environments e ON e.id = a.environment_id
       ${filter}
       ORDER BY a.created_at DESC
       LIMIT $${params.length + 1}`,
      [...params, limit]
    );
    return res.json({ logs: result.rows });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;