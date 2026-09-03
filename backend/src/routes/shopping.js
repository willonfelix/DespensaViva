const express = require('express');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');
const requireEnvironment = require('../middlewares/environment');
const { syncShoppingList } = require('./pantry');

const router = express.Router();
router.use(requireAuth);
router.use(requireEnvironment);

// GET /api/shopping-list
// Retorna pendências explícitas + itens automaticamente abaixo do mínimo.
router.get('/', async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT sl.id, sl.product_id AS "productId",
              p.name, p.unit_of_measure AS "unitOfMeasure",
              c.name AS category,
              sl.quantity AS suggestedQuantity,
              sl.is_checked AS "isChecked"
       FROM shopping_list sl
       JOIN products p ON sl.product_id = p.id
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE sl.environment_id = $1 AND sl.is_checked = FALSE
       ORDER BY p.name`,
      [req.environmentId]
    );
    return res.json({ items: result.rows });
  } catch (err) {
    return next(err);
  }
});

// POST /api/shopping-list/sync
// Recalcula a lista automática de compras para o ambiente ativo.
router.post('/sync', async (req, res, next) => {
  try {
    const lowStock = await db.query(
      `SELECT pi.product_id AS "productId", pi.quantity, pi.min_quantity AS "minQuantity",
              p.name, p.unit_of_measure AS "unitOfMeasure"
       FROM pantry_items pi
       JOIN products p ON pi.product_id = p.id
       WHERE pi.environment_id = $1 AND pi.quantity <= pi.min_quantity`,
      [req.environmentId]
    );

    await db.transaction(async (client) => {
      for (const row of lowStock.rows) {
        await syncShoppingList(
          client,
          req.environmentId,
          row.productId,
          null,
          row.unitOfMeasure,
          row.quantity,
          row.minQuantity
        );
      }
      return lowStock.rows.length;
    });

    const result = await db.query(
      `SELECT sl.id, sl.product_id AS "productId",
              p.name, p.unit_of_measure AS "unitOfMeasure",
              c.name AS category,
              sl.quantity AS suggestedQuantity,
              sl.is_checked AS "isChecked"
       FROM shopping_list sl
       JOIN products p ON sl.product_id = p.id
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE sl.environment_id = $1 AND sl.is_checked = FALSE
       ORDER BY p.name`,
      [req.environmentId]
    );
    return res.json({ items: result.rows });
  } catch (err) {
    return next(err);
  }
});

// PATCH /api/shopping-list/:id (marca como comprado/desmarcado)
router.patch('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { is_checked } = req.body || {};

    const result = await db.query(
      `UPDATE shopping_list SET is_checked = $1
       WHERE id = $2 AND environment_id = $3 AND is_checked = $4
       RETURNING id, product_id AS "productId", quantity, is_checked AS "isChecked"`,
      [is_checked ? true : false, id, req.environmentId, is_checked ? false : true]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item não encontrado na lista de compras.' });
    }
    return res.json({ item: result.rows[0] });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/shopping-list/:id (remove manualmente um item)
router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await db.query(
      'DELETE FROM shopping_list WHERE id = $1 AND environment_id = $2 RETURNING id',
      [id, req.environmentId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item não encontrado na lista de compras.' });
    }
    return res.status(204).end();
  } catch (err) {
    return next(err);
  }
});

// POST /api/shopping-list/buy
// Finaliza a compra dos itens marcados: soma a quantidade comprada na dispensa
// e remove os registros concluídos da lista.
router.post('/buy', async (req, res, next) => {
  try {
    await db.transaction(async (client) => {
      const checked = await client.query(
        `SELECT id, product_id AS "productId", quantity
         FROM shopping_list
         WHERE environment_id = $1 AND is_checked = TRUE`,
        [req.environmentId]
      );

      for (const row of checked.rows) {
        const existing = await client.query(
          'SELECT min_quantity FROM pantry_items WHERE environment_id = $1 AND product_id = $2',
          [req.environmentId, row.productId]
        );
        const minQty =
          existing.rows.length > 0
            ? Number(existing.rows[0].min_quantity)
            : 0;

        await client.query(
          `INSERT INTO pantry_items (environment_id, product_id, quantity, min_quantity)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (environment_id, product_id)
           DO UPDATE SET quantity = pantry_items.quantity + EXCLUDED.quantity,
                         min_quantity = GREATEST(pantry_items.min_quantity, EXCLUDED.min_quantity)`,
          [req.environmentId, row.productId, Number(row.quantity), minQty]
        );
        await client.query(
          'DELETE FROM shopping_list WHERE id = $1 AND environment_id = $2',
          [row.id, req.environmentId]
        );
      }
      return checked.rows; // se estiver vazio, apenas COMMIT (no-op)
    });

    return res.json({ success: true });
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
