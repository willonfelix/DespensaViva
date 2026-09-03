require('dotenv').config();
const express = require('express');
const cors = require('cors');
const db = require('./config/db');
const { runMigrations } = require('./config/migrate');

const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const environmentRoutes = require('./routes/environments');
const pantryRoutes = require('./routes/pantry');
const shoppingRoutes = require('./routes/shopping');
const profileRoutes = require('./routes/profile');
const suggestionRoutes = require('./routes/suggestions');

const app = express();

app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/environments', environmentRoutes);
app.use('/api/pantry', pantryRoutes);
app.use('/api/shopping-list', shoppingRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/suggestions', suggestionRoutes);

// 404 para rotas desconhecidas
app.use((req, res) => {
  res.status(404).json({ error: 'Rota não encontrada.' });
});

// Middleware de erro centralizado
app.use((err, req, res, next) => {
  console.error('[Erro]', err.message);
  if (err.code === '23505') {
    return res.status(409).json({ error: 'Registro duplicado.' });
  }
  return res.status(500).json({ error: 'Erro interno do servidor.' });
});

const PORT = process.env.PORT || 3007;

async function start() {
  try {
    await db.query('SELECT 1');
    console.log('Conexão com o PostgreSQL OK.');
    await runMigrations();
  } catch (err) {
    console.error('Falha ao conectar ao PostgreSQL:', err.message);
    process.exit(1);
  }
  app.listen(PORT, () => {
    console.log(`API DespensaViva rodando em http://localhost:${PORT}`);
  });
}

start();