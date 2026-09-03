const express = require('express');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');
const { mapCategory } = require('../config/off_categories');

const router = express.Router();
router.use(requireAuth);

const OFF_URL = 'https://world.openfoodfacts.org/api/v2/product';

async function resolveCategoryId(categoryName) {
  if (!categoryName) return null;
  const result = await db.query(
    'SELECT id FROM categories WHERE LOWER(name) = LOWER($1)',
    [categoryName]
  );
  return result.rows.length > 0 ? result.rows[0].id : null;
}

// Busca produto pelo código de barras na Open Food Facts
router.get('/:code', async (req, res, next) => {
  try {
    const code = String(req.params.code || '').replace(/[^0-9]/g, '');
    if (!code) {
      return res.status(400).json({ error: 'Código de barras inválido.' });
    }

    let data;
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 10000);
      const response = await fetch(`${OFF_URL}/${code}.json`, {
        signal: controller.signal,
        headers: { 'User-Agent': 'DespensaViva/1.0 (controle de dispensa)' },
      });
      clearTimeout(timeout);
      data = await response.json();
    } catch (err) {
      return res
        .status(502)
        .json({ error: 'Não foi possível consultar a base de produtos online.' });
    }

    if (!data || data.status !== 1 || !data.product) {
      return res
        .status(404)
        .json({ error: 'Produto não encontrado para este código de barras.' });
    }

    const p = data.product;
    let name =
      p.product_name ||
      p.product_name_pt ||
      (p._keywords && p._keywords.length > 0 ? p._keywords[0] : null) ||
      '';
    name = name.trim();

    const offCategory = Array.isArray(p.categories_tags)
      ? p.categories_tags[0]
      : null;
    const localCategory = mapCategory(offCategory);
    const categoryId = await resolveCategoryId(localCategory);

    return res.json({
      product: {
        name,
        brand: (p.brands || '').trim() || null,
        category: localCategory,
        categoryId,
        imageUrl: p.image_front_url || p.image_url || null,
      },
    });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
