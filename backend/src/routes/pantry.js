const express = require('express');
const db = require('../config/data');
const requireAuth = require('../middlewares/auth');
const requireEnvironment = require('../middlewares/environment');

const router = express.Router();
router.use(requireAuth);
router.use(requireEnvironment);

function insertAudit(client, userId, environmentId, action, entity, entityId, details) {
  return client.query(
    `INSERT INTO audit_logs (user_id, environment_id, action, entity, entity_id, details)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [userId, environmentId, action, entity, entityId, details ? JSON.stringify(details) : null]
  );
}

// Garante que o item entra na lista de compras se quantity <= min_quantity
async function syncShoppingList(client, environmentId, productId, productName, unitOfMeasure, quantity, minQuantity) {
  if (Number(quantity) <= Number(minQuantity)) {
    const suggested = Math.max(Number(minQuantity) * 2 - Number(quantity), Number(minQuantity));
    await client.query(
      `INSERT INTO shopping_list (environment_id, product_id, quantity, is_checked)
       VALUES ($1, $2, $3, FALSE)
       ON CONFLICT (environment_id, product_id, is_checked)
       DO UPDATE SET quantity = EXCLUDED.quantity`,
      [environmentId, productId, suggested]
    );
  } else {
    // Estoque suficiente: remove pendências da lista de compras deste produto
    await client.query(
      `DELETE FROM shopping_list
       WHERE environment_id = $1 AND product_id = $2 AND is_checked = FALSE`,
      [environmentId, productId]
    );
  }
  return productName;
}

router.get('/', async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT pi.id, pi.product_id AS "productId",
              p.name, p.unit_of_measure AS "unitOfMeasure",
              c.id AS "categoryId", c.name AS category,
              pi.quantity, pi.min_quantity AS "minQuantity",
              pi.expiration_date AS "expirationDate",
              pi.updated_at AS "updatedAt"
       FROM pantry_items pi
       JOIN products p ON pi.product_id = p.id
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE pi.environment_id = $1
       ORDER BY p.name`,
      [req.environmentId]
    );
    return res.json({ items: result.rows });
  } catch (err) {
    return next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const { name, category_id, unit_of_measure, quantity, min_quantity, expiration_date } = req.body || {};

    if (!name || !String(name).trim()) {
      return res.status(400).json({ error: 'Informe o nome do produto.' });
    }
    if (quantity == null || min_quantity == null) {
      return res.status(400).json({ error: 'Informe quantidade atual e mínima.' });
    }

    const unit = ['kg', 'g', 'litro', 'ml', 'unidade', 'pacote', 'lata', 'garrafa'].includes(unit_of_measure)
      ? unit_of_measure
      : 'unidade';

    await db.transaction(async (client) => {
      let productId;
      const existing = await client.query(
        'SELECT id FROM products WHERE LOWER(name) = LOWER($1) AND unit_of_measure = $2',
        [String(name).trim(), unit]
      );
      if (existing.rows.length > 0) {
        productId = existing.rows[0].id;
        if (category_id) {
          await client.query('UPDATE products SET category_id = $1 WHERE id = $2', [category_id, productId]);
        }
      } else {
        const created = await client.query(
          `INSERT INTO products (name, category_id, unit_of_measure)
           VALUES ($1, $2, $3)
           ON CONFLICT (name, unit_of_measure) DO NOTHING
           RETURNING id`,
          [String(name).trim(), category_id || null, unit]
        );
        if (created.rows.length > 0) {
          productId = created.rows[0].id;
        } else {
          const again = await client.query(
            'SELECT id FROM products WHERE LOWER(name) = LOWER($1) AND unit_of_measure = $2',
            [String(name).trim(), unit]
          );
          productId = again.rows[0].id;
        }
      }

      const qty = Number(quantity);
      const minQty = Number(min_quantity);
      const expDate = expiration_date ? new Date(expiration_date) : null;

      const item = await client.query(
        `INSERT INTO pantry_items (environment_id, product_id, quantity, min_quantity, expiration_date)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (environment_id, product_id)
         DO UPDATE SET quantity = EXCLUDED.quantity,
                       min_quantity = EXCLUDED.min_quantity,
                       expiration_date = EXCLUDED.expiration_date
         RETURNING id, quantity, min_quantity AS "minQuantity",
                   expiration_date AS "expirationDate"`,
        [req.environmentId, productId, qty, minQty, expDate]
      );

      await syncShoppingList(client, req.environmentId, productId, null, unit, qty, minQty);
      await insertAudit(
        client,
        req.userId,
        req.environmentId,
        'pantry.add',
        'pantry_item',
        String(productId),
        { name: String(name).trim(), unit, quantity: qty }
      );
      res.status(201).json({
        item: {
          id: item.rows[0].id,
          productId,
          name: String(name).trim(),
          unitOfMeasure: unit,
          quantity: qty,
          minQuantity: minQty,
          expirationDate: expDate,
        },
      });
    });
  } catch (err) {
    return next(err);
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { quantity, min_quantity, expiration_date } = req.body || {};

    const current = await db.query(
      'SELECT product_id, quantity, min_quantity FROM pantry_items WHERE id = $1 AND environment_id = $2',
      [id, req.environmentId]
    );
    if (current.rows.length === 0) {
      return res.status(404).json({ error: 'Item não encontrado na dispensa.' });
    }

    const row = current.rows[0];
    const fields = [];
    const params = [];
    let p = 1;

    if (quantity != null) {
      fields.push(`quantity = $${p++}`);
      params.push(Number(quantity));
    }
    if (min_quantity != null) {
      fields.push(`min_quantity = $${p++}`);
      params.push(Number(min_quantity));
    }
    if (expiration_date !== undefined) {
      fields.push(`expiration_date = $${p++}`);
      params.push(expiration_date ? new Date(expiration_date) : null);
    }
    if (fields.length === 0) {
      return res.status(400).json({ error: 'Nenhum campo informado para atualização.' });
    }

    params.push(id, req.environmentId);
    const result = await db.query(
      `UPDATE pantry_items SET ${fields.join(', ')}
       WHERE id = $${p} AND environment_id = $${p + 1}
       RETURNING id, product_id AS "productId", quantity,
                 min_quantity AS "minQuantity", expiration_date AS "expirationDate"`,
      params
    );

    const updated = result.rows[0];
    const finalQty = updated.quantity == null ? row.quantity : updated.quantity;
    const finalMin = updated.minQuantity == null ? row.min_quantity : updated.minQuantity;

    await db.transaction(async (client) => {
      await syncShoppingList(
        client,
        req.environmentId,
        updated.productId,
        null,
        null,
        finalQty,
        finalMin
      );
      return updated;
    });

    return res.json({ item: updated });
  } catch (err) {
    return next(err);
  }
});

// POST /api/pantry/pending — pendências de quantidade do usuário no ambiente ativo
router.get('/pending', async (req, res, next) => {
  try {
    const result = await db.query(
      `SELECT pc.id, pc.pantry_item_id AS "pantryItemId",
              p.name, p.unit_of_measure AS "unitOfMeasure",
              pi.quantity AS "currentQuantity", pc.new_quantity AS "newQuantity"
       FROM pending_quantity_changes pc
       JOIN pantry_items pi ON pi.id = pc.pantry_item_id
       JOIN products p ON p.id = pi.product_id
       WHERE pc.environment_id = $1 AND pc.user_id = $2
       ORDER BY pc.created_at DESC`,
      [req.environmentId, req.userId]
    );
    return res.json({ pending: result.rows });
  } catch (err) {
    return next(err);
  }
});

// POST /api/pantry/confirm — aplica pendências do usuário, atualiza estoque e audita
router.post('/confirm', async (req, res, next) => {
  try {
    const applied = await db.transaction(async (client) => {
      const pendings = await client.query(
        `SELECT pc.id AS pending_id, pc.pantry_item_id AS "pantryItemId",
                pc.new_quantity AS "newQuantity",
                pi.quantity AS "currentQuantity", pi.min_quantity AS "minQuantity",
                p.id AS "productId", p.name, p.unit_of_measure AS "unitOfMeasure"
         FROM pending_quantity_changes pc
         JOIN pantry_items pi ON pi.id = pc.pantry_item_id
         JOIN products p ON p.id = pi.product_id
         WHERE pc.environment_id = $1 AND pc.user_id = $2`,
        [req.environmentId, req.userId]
      );

      const appliedItems = [];
      for (const row of pendings.rows) {
        const oldQty = Number(row.currentQuantity);
        const newQty = Number(row.newQuantity);
        await client.query(
          'UPDATE pantry_items SET quantity = $1 WHERE id = $2',
          [newQty, row.pantryItemId]
        );
        await syncShoppingList(
          client,
          req.environmentId,
          row.productId,
          null,
          row.unitOfMeasure,
          newQty,
          Number(row.minQuantity)
        );
        await insertAudit(
          client,
          req.userId,
          req.environmentId,
          'pantry.quantity_change',
          'pantry_item',
          String(row.pantryItemId),
          { name: row.name, unit: row.unitOfMeasure, old_quantity: oldQty, new_quantity: newQty }
        );
        await client.query('DELETE FROM pending_quantity_changes WHERE id = $1', [row.pending_id]);
        appliedItems.push({
          pantryItemId: row.pantryItemId,
          name: row.name,
          unitOfMeasure: row.unitOfMeasure,
          oldQuantity: oldQty,
          newQuantity: newQty,
        });
      }
      return appliedItems;
    });

    return res.json({ applied: applied.length, items: applied });
  } catch (err) {
    return next(err);
  }
});

// POST /api/pantry/:id/stage — grava pendência de mudança de quantidade
router.post('/:id/stage', async (req, res, next) => {
  try {
    const { id } = req.params;
    const { quantity } = req.body || {};
    const newQty = Number(quantity);
    if (quantity == null || !Number.isFinite(newQty) || newQty < 0) {
      return res.status(400).json({ error: 'Informe uma quantidade válida.' });
    }

    const current = await db.query(
      'SELECT id, quantity FROM pantry_items WHERE id = $1 AND environment_id = $2',
      [id, req.environmentId]
    );
    if (current.rows.length === 0) {
      return res.status(404).json({ error: 'Item não encontrado na dispensa.' });
    }

    const currentQty = Number(current.rows[0].quantity);
    if (newQty === currentQty) {
      await db.query(
        'DELETE FROM pending_quantity_changes WHERE pantry_item_id = $1 AND user_id = $2',
        [id, req.userId]
      );
      return res.json({ status: 'cleared' });
    }

    await db.query(
      `INSERT INTO pending_quantity_changes (environment_id, user_id, pantry_item_id, new_quantity)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, pantry_item_id)
       DO UPDATE SET new_quantity = EXCLUDED.new_quantity, created_at = CURRENT_TIMESTAMP`,
      [req.environmentId, req.userId, id, newQty]
    );
    return res.json({ status: 'staged', new_quantity: newQty });
  } catch (err) {
    return next(err);
  }
});

// DELETE /api/pantry/pending/:id — cancela uma pendência
router.delete('/pending/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    await db.query(
      'DELETE FROM pending_quantity_changes WHERE id = $1 AND user_id = $2',
      [id, req.userId]
    );
    return res.status(204).end();
  } catch (err) {
    return next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const current = await db.query(
      `SELECT pi.id, p.name, pi.product_id, p.unit_of_measure AS "unitOfMeasure", pi.quantity
       FROM pantry_items pi
       JOIN products p ON p.id = pi.product_id
       WHERE pi.id = $1 AND pi.environment_id = $2`,
      [id, req.environmentId]
    );
    if (current.rows.length === 0) {
      return res.status(404).json({ error: 'Item não encontrado na dispensa.' });
    }
    const row = current.rows[0];
    await db.transaction(async (client) => {
      await client.query(
        'DELETE FROM pending_quantity_changes WHERE pantry_item_id = $1 AND environment_id = $2',
        [id, req.environmentId]
      );
      await client.query(
        'DELETE FROM pantry_items WHERE id = $1 AND environment_id = $2',
        [id, req.environmentId]
      );
      await insertAudit(
        client,
        req.userId,
        req.environmentId,
        'pantry.delete',
        'pantry_item',
        String(id),
        { name: row.name, unit: row.unitOfMeasure, quantity: row.quantity }
      );
    });
    return res.status(204).end();
  } catch (err) {
    return next(err);
  }
});

module.exports = router;
module.exports.syncShoppingList = syncShoppingList;
