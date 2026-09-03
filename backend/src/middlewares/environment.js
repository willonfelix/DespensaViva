const db = require('../config/data');

// Garante que o usuário autenticado (req.userId) é membro do ambiente
// informado no header X-Environment-Id, injetando req.environmentId e req.role.
module.exports = async function requireEnvironment(req, res, next) {
  try {
    const envId = req.headers['x-environment-id'];
    if (!envId) {
      return res.status(400).json({ error: 'Ambiente não informado (X-Environment-Id).' });
    }

    const result = await db.query(
      'SELECT role FROM environment_members WHERE environment_id = $1 AND user_id = $2',
      [envId, req.userId]
    );
    if (result.rows.length === 0) {
      return res.status(403).json({ error: 'Acesso negado a este ambiente.' });
    }

    req.environmentId = envId;
    req.environmentRole = result.rows[0].role;
    return next();
  } catch (err) {
    return next(err);
  }
};
