const { verifyToken } = require('../config/auth');

module.exports = function requireAuth(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'Token não informado.' });
    }

    const payload = verifyToken(token);
    req.userId = payload.sub;
    req.userEmail = payload.email;
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Sessão inválida ou expirada. Faça login novamente.' });
  }
};