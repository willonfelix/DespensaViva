const express = require('express');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');

const router = express.Router();
router.use(requireAuth);

const UNITS = ['kg', 'g', 'litro', 'ml', 'unidade', 'pacote', 'lata', 'garrafa'];

router.get('/categories', async (req, res, next) => {
  try {
    const result = await db.query('SELECT id, name FROM categories ORDER BY name');
    return res.json({ categories: result.rows });
  } catch (err) {
    return next(err);
  }
});

router.get('/units', (req, res) => {
  res.json({ units: UNITS });
});

router.get('/', async (req, res, next) => {
  try {
    const { search } = req.query;
    let text = `
      SELECT p.id, p.name, p.unit_of_measure AS "unitOfMeasure",
             p.category_id AS "categoryId", c.name AS category
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
    `;
    const params = [];
    if (search) {
      params.push(`%${String(search).toLowerCase()}%`);
      text += ` WHERE LOWER(p.name) LIKE $1`;
    }
    text += ' ORDER BY p.name';
    const result = await db.query(text, params);
    return res.json({ products: result.rows });
  } catch (err) {
    return next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { name, category_id, unit_of_measure } = req.body || {};
    const unit = UNITS.includes(unit_of_measure) ? unit_of_measure : 'unidade';

    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Informe o nome do produto.' });
    }

    const result = await db.query(
      `INSERT INTO products (name, category_id, unit_of_measure)
       VALUES ($1, $2, $3)
       ON CONFLICT (name, unit_of_measure)
       DO UPDATE SET name = EXCLUDED.name
       RETURNING id, name, category_id AS "categoryId", unit_of_measure AS "unitOfMeasure"`,
      [String(name).trim(), category_id || null, unit]
    );
    return res.status(201).json({ product: result.rows[0] });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;