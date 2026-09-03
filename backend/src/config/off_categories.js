// Mapeia categorias da Open Food Facts para as categorias locais do DespensaViva.

// Palavras-chave (inglês/pt) por categoria local.
const LOCAL_CATEGORIES = {
  'Grãos e Cereais': ['cereals', 'grains', 'rice', 'pasta', 'flour', 'bread', 'cereal'],
  'Mercearia e Temperos': [
    'sauces', 'spices', 'condiment', 'oil', 'vinegar', 'sugar', 'salt', 'canned',
    'molho', 'tempero', 'óleo', 'vinagre', 'açúcar', 'sal', 'enlatado', 'café', 'coffee', 'tea', 'chá',
  ],
  'Laticínios': ['dairy', 'milk', 'cheese', 'yogurt', 'butter', 'cream'],
  'Limpeza': ['cleaning', 'detergent', 'cleaner', 'soap', 'hygiene'],
  'Bebidas': ['beverages', 'drinks', 'juice', 'soda', 'soft drink', 'beer', 'wine', 'water'],
  'Hortifrúti': ['fruits', 'vegetables', 'fruit', 'vegetable', 'produce'],
  'Congelados': ['frozen'],
  'Carnes': ['meat', 'chicken', 'beef', 'pork', 'fish', 'seafood', 'sausage', 'carnes'],
};

// Retorna o nome da categoria local correspondente, ou null se não mapeou.
function mapCategory(offCategory) {
  const text = (offCategory || '').toLowerCase();
  if (!text) return null;

  for (const [localName, keywords] of Object.entries(LOCAL_CATEGORIES)) {
    for (const kw of keywords) {
      if (text.includes(kw)) {
        return localName;
      }
    }
  }
  return null;
}

module.exports = { mapCategory };
