# Plano: Cadastro de Produto com Scanner de Código de Barras + Busca Open Food Facts

**Data:** 03/09/2026
**Status:** Aprovado — em implementação

---

## Visão Geral

Adicionar ao cadastro de produto a opção de escanear por **câmera** (`mobile_scanner`) e/ou **digitar manualmente** o código de barras. O sistema busca o produto na **Open Food Facts** (endpoint exato por barcode, grátis e sem key), pré-preenche nome/marca/categoria para confirmação na tela de cadastro existente.

## Decisões (aprovadas)

| Tópico | Decisão |
|---|---|
| Escaneamento | Câmera (`mobile_scanner`) no Android + digitação manual (fallback na web, onde plugin é instável) |
| Fonte de busca | Open Food Facts — `world.openfoodfacts.org/api/v2/product/{code}.json` |
| Dados capturados | Nome, marca, categoria (mapeada às categorias locais) |
| Fluxo | Prefill + confirmação |
| Busca | Sempre em tempo real (sem cache persistente) |
| Imagem | Exibida na prévia, **não** persistida no banco |

---

## Backend

### 1. `backend/src/config/off_categories.js` (criar)
- Mapa de palavras-chave OFF → categoria local (8 existentes: Grãos e Cereais, Mercearia e Temperos, Laticínios, Limpeza, Bebidas, Hortifrúti, Congelados, Carnes)
- `mapCategory(offCategory) → nome local | null`
- Função para buscar `categories.id` pelo nome mapeado

### 2. `backend/src/routes/barcode.js` (criar)
- **GET `/api/barcode/:code`** — autenticado (`requireAuth`)
- Valida `code` (só dígitos)
- `fetch` nativo (Node 20) → Open Food Facts
- OFF `status === 0` → 404 com mensagem clara
- Mapeia resposta:
  - `name` ← `product_name` (fallback `_pt`/`_keywords`)
  - `brand` ← `brands`
  - `category`/`categoryId` ← primeiro item de `categories`, mapeado local
  - `imageUrl` ← `image_front_url`
- Trata erro de rede/timeout → 500

### 3. `backend/src/server.js` (editar)
- `app.use('/api/barcode', barcodeRoutes)`

**Retorno `/api/barcode/:code`:**
```json
{ "product": { "name": "...", "brand": "...", "category": "...", "categoryId": 3, "imageUrl": "..." } }
```
`categoryId` `null` se não mapeou (dropdown aberto).

---

## Frontend

### 4. `app/pubspec.yaml` (editar)
- Adicionar `mobile_scanner: ^7.x`

### 5. `app/lib/models/product_suggestion.dart` (criar)
- `name`, `brand`, `categoryId` (int?), `imageUrl`

### 6. `app/lib/features/products/barcode_controller.dart` (criar)
- `BarcodeState`: `searching`, `searched`, `found`, `suggestion`, `error`, `source` (camera/manual)
- Métodos: `searchByCode(code)`, `clear()`

### 7. `app/lib/features/products/barcode_scanner_screen.dart` (criar)
- Fullscreen `MobileScanner`
- `onDetect` com debounce → fecha tela → chama `searchByCode(code)`
- Botão cancelar; hint de digitação manual na web

### 8. `app/lib/features/products/add_product_screen.dart` (editar)
- Barra de ações: botão "Escanear" + campo "Código de barras" + botão "Buscar"
- Estados: spinner / erro / Card de prévia (imagem, nome, marca, categoria) + botão "Usar dados"
- "Usar dados" → preenche nome, unidade, `_selectedCategoryId`
- `_save()` permanece (nome editável)

---

## Índice de arquivos

| Arquivo | Ação |
|---|---|
| `backend/src/config/off_categories.js` | criar |
| `backend/src/routes/barcode.js` | criar |
| `backend/src/server.js` | editar |
| `app/pubspec.yaml` | editar |
| `app/lib/models/product_suggestion.dart` | criar |
| `app/lib/features/products/barcode_controller.dart` | criar |
| `app/lib/features/products/barcode_scanner_screen.dart` | criar |
| `app/lib/features/products/add_product_screen.dart` | editar |

---

## Segurança / notas

- Open Food Facts é pública e gratuita, sem key; chamada centralizada no backend (evita CORS e centraliza o mapeamento de categorias).
- Categoria mapeada é sugestão — o usuário pode trocar no dropdown.
- Sem mudança de schema de banco (busca em tempo real).
- Câmera prioritária no Android; na web, digitação manual (mobile_scanner web é instável).
