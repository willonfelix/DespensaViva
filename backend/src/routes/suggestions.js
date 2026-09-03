const express = require('express');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');
const requireEnvironment = require('../middlewares/environment');

const router = express.Router();
router.use(requireAuth);
router.use(requireEnvironment);

function buildPrompt(items) {
  const list = items
    .map((i) => `${i.name}: ${i.quantity} ${i.unit_of_measure}`)
    .join('\n');

  return `Você é um assistente culinário inteligente. Analise os itens disponíveis na despensa e sugira:
1. Receitas que usem o maior número de itens possíveis
2. Combinações criativas entre os itens
3. Dicas para usar itens com pouca quantidade
4. Avisos sobre itens próximos ao vencimento, se houver

Itens da despensa:
${list}

Responda de forma objetiva e prática, em formato markdown.`;
}

router.post('/generate', async (req, res, next) => {
  try {
    const userResult = await db.query(
      'SELECT gemini_api_key FROM users WHERE id = $1',
      [req.userId]
    );
    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'Usuário não encontrado.' });
    }
    const apiKey = userResult.rows[0].gemini_api_key;
    if (!apiKey) {
      return res.status(400).json({
        error: 'Cadastre sua chave da API Google (Gemini) na tela de Perfil para gerar sugestões.',
      });
    }

    const pantry = await db.query(
      `SELECT p.name, pi.quantity, p.unit_of_measure
       FROM pantry_items pi
       JOIN products p ON pi.product_id = p.id
       WHERE pi.environment_id = $1
       ORDER BY p.name`,
      [req.environmentId]
    );

    if (pantry.rows.length === 0) {
      return res.status(400).json({ error: 'Sua dispensa está vazia. Adicione itens para gerar sugestões.' });
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
    const result = await model.generateContent(buildPrompt(pantry.rows));
    const text = result.response.text();

    return res.json({
      suggestions: text,
      generated_at: new Date().toISOString(),
    });
  } catch (err) {
    if (err.status === 400 || (err.message && /API key/i.test(err.message))) {
      return res.status(400).json({ error: 'Chave da API Gemini inválida. Verifique na tela de Perfil.' });
    }
    return next(err);
  }
});

module.exports = router;
