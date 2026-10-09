# Plano: Sugestões Inteligentes (IA Gemini) + Tela de Perfil

**Data:** 03/09/2026
**Status:** Aprovado — em implementação

---

## Visão Geral

Duas funcionalidades novas:

1. **Tela de Perfil** — usuário troca senha e cadastra sua própria API Key do Gemini Flash. A chave é armazenada por usuário no banco de dados (nunca exposta em texto plano pela API).
2. **Aba Sugestões** — IA (Gemini Flash) analisa os itens da dispensa do ambiente ativo e sugere receitas, combinações e uso consciente/estratégico dos ingredientes. Cache no frontend (localStorage) com TTL de 6 horas.

**Objetivo de negócio:** estimular o uso consciente e estratégico dos ingredientes já presentes na despensa, reduzindo desperdício.

---

## Decisões de Design (aprovadas)

| Tópico | Decisão |
|---|---|
| Modelo IA | `gemini-1.5-flash` |
| Apresentação | Quarta aba no bottom navigation (Dispensa, Compras, Dispensas, Sugestões) |
| Gatilho | Sob demanda + cache |
| Dados enviados à IA | Somente itens + quantidade + unidade (+ nome) |
| API Key | Por usuário, cadastrada na tela de perfil, salva no banco |
| Cache | Frontend (localStorage via `flutter_secure_storage`), TTL 6h |
| Markdown | `flutter_markdown` (novo pacote) |
| Migration | Script `.sql` aplicado automaticamente no startup do backend |

---

## 1. Schema do banco — coluna `gemini_api_key`

**Editar:** `backend/db/schema.sql` (tabela `users`, após `created_at`)
```sql
gemini_api_key TEXT
```

**Criar migration reutilizável:** `backend/db/migrations/001_add_gemini_api_key.sql`
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS gemini_api_key TEXT;
```

**Migration automática no startup do backend** (`backend/src/server.js`, antes de `app.listen`):
- Lê diretório `backend/db/migrations/*.sql` em ordem alfabética
- Roda cada arquivo ainda não registrado (tabela `schema_migrations` de controle, ou aplicação idempotente via `IF NOT EXISTS`)
- Imprime log de migrações executadas

---

## 2. Backend — Routa de perfil (`backend/src/routes/profile.js`)

| Método | Rota | Descrição |
|---|---|---|
| GET | `/api/profile` | Dados do usuário + `has_gemini_key` (boolean). NUNCA retorna a key em texto plano |
| PUT | `/api/profile/password` | Troca senha — body `{ current_password, new_password }`. Valida senha atual com bcrypt, nova senha ≥ 6 chars |
| PUT | `/api/profile/gemini-key` | Salva/atualiza key — body `{ gemini_key }`. Enviar `""` remove a key |

**Montagem:** `app.use('/api/profile', profileRoutes)` em `server.js`.

---

## 3. Backend — Routa de sugestões (`backend/src/routes/suggestions.js`)

| Método | Rota | Descrição |
|---|---|---|
| POST | `/api/suggestions/generate` | Busca itens da dispensa do ambiente ativo, chama Gemini Flash, retorna sugestões |

**Fluxo:**
1. `requireAuth` + `requireEnvironment`
2. Valida usuário tem `gemini_api_key` → senão 400 com orientação a cadastrar na tela de perfil
3. Query itens da dispensa restrita ao `req.environmentId` (nome, quantidade, unidade)
4. Monta prompt + chama `gemini-1.5-flash` via `@google/generative-ai`
5. Retorna `{ suggestions: "markdown", generated_at: ISO }`

**Prompt de referência:**
```
Você é um assistente culinário inteligente. Analise os itens disponíveis na despensa e sugira:
1. Receitas que usem o maior número de itens possíveis
2. Combinações criativas entre os itens
3. Dicas para usar itens com pouca quantidade
4. Avisos sobre itens próximos ao vencimento

Itens da despensa:
- Arroz: 2 kg
- Feijão: 1 kg
- Óleo de soja: 500 ml
...

Responda de forma objetiva e prática, em formato markdown.
```

**Dependência:** `npm install @google/generative-ai` em `backend/`.

---

## 4. Backend — `/me` com `has_gemini_key`

**Editar:** `backend/src/routes/auth.js` (GET `/me`)
- SELECT adiciona `gemini_api_key IS NOT NULL AS has_gemini_key`
- Resposta inclui `has_gemini_key`, nunca a key em si.

---

## 5. Frontend — Model User

**Editar:** `app/lib/models/user.dart`
- Adicionar `bool hasGeminiKey`
- `fromJson` lê `has_gemini_key`

---

## 6. Frontend — Tela de Perfil

**Criar:**
- `app/lib/features/profile/profile_screen.dart`
- `app/lib/features/profile/profile_controller.dart` (Riverpod StateNotifier)

**Controller:**
- `ProfileState`: `user`, `loading`, `error`, `successMessage`
- Métodos: `updatePassword(atual, nova)`, `saveGeminiKey(key)`, `clearGeminiKey()`

**Tela:** acessível via ícone `Icons.person_outline` no AppBar.
- Dados do usuário (nome, email)
- Campo API Key Gemini (toggle mostrar/ocultar, salvar/limpar)
- Campos troca de senha (atual, nova, confirmar)
- Snackbar de sucesso/erro

---

## 7. Frontend — AuthController propaga `hasGeminiKey`

**Editar:** `app/lib/features/auth/auth_controller.dart`
- Ao carregar user do `/me`, consome `has_gemini_key` no `User`.

---

## 8. Frontend — Tela de Sugestões

**Criar:**
- `app/lib/features/suggestions/suggestions_screen.dart`
- `app/lib/features/suggestions/suggestions_controller.dart`

**Controller:**
- `SuggestionsState`: `suggestions` (String?), `loading`, `error`, `generatedAt`, `cachedUntil`
- `generate(environmentId)`: verifica cache (TTL 6h) → se válido usa, senão chama `POST /suggestions/generate`, salva cache em `flutter_secure_storage` (chave `suggestions_{environmentId}`)
- `loadCached(environmentId)`: restaura cache ao abrir a aba

**Tela:**
- Sem key cadastrada → card orientando a ir ao perfil
- Loading → spinner
- Renderiza markdown com `flutter_markdown`
- Botão "Gerar novas sugestões" (força regeneração)
- Timestamp "Gerado em: DD/MM/YYYY HH:mm"

---

## 9. Frontend — Navegação (HomeScreen)

**Editar:** `app/lib/features/home/home_screen.dart`
- `IndexedStack.children` ganha `SuggestionsScreen()`
- `NavigationBar` ganha 4º destino `Sugestões` (`Icons.lightbulb_outline`/`Icons.lightbulb`)
- AppBar: adiciona action `Icons.person_outline` → `ProfileScreen`; mantém logout

---

## 10. Frontend — dependência markdown

**Editar:** `app/pubspec.yaml`
- Adicionar `flutter_markdown`

---

## 11. Index de arquivos afetados

| Arquivo | Ação |
|---|---|
| `backend/db/schema.sql` | editar (add coluna) |
| `backend/db/migrations/001_add_gemini_api_key.sql` | criar |
| `backend/src/server.js` | editar (migration runner + mount rotas) |
| `backend/src/routes/profile.js` | criar |
| `backend/src/routes/suggestions.js` | criar |
| `backend/src/routes/auth.js` | editar (`has_gemini_key` no `/me`) |
| `backend/package.json` | editar (`@google/generative-ai`) |
| `app/pubspec.yaml` | editar (`flutter_markdown`) |
| `app/lib/models/user.dart` | editar (`hasGeminiKey`) |
| `app/lib/features/auth/auth_controller.dart` | editar |
| `app/lib/features/home/home_screen.dart` | editar (4 tabs + ícone perfil) |
| `app/lib/features/profile/profile_screen.dart` | criar |
| `app/lib/features/profile/profile_controller.dart` | criar |
| `app/lib/features/suggestions/suggestions_screen.dart` | criar |
| `app/lib/features/suggestions/suggestions_controller.dart` | criar |

---

## Segurança / Notas

- A API Key Gemini **nunca** é retornada em texto plano — apenas `has_gemini_key`.
- Key fica no banco apenas cifrada como texto (nenhum requisito de criptografia adicional neste escopo; revisar se necessário).
- O cache de sugestões é por ambiente e fica no dispositivo do usuário; não é compartilhado entre membros (aceito por decisão).
- Sem key cadastrada, a rota de sugestões devolve 400 com mensagem clara.
