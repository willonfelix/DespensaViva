# Plano de Evolução: Ambientes (Dispensas) Compartilhados

## Objetivo

Permitir que um usuário entre com sua conta e crie **ambientes do tipo "Dispensa"**, dando um nome e adicionando outros usuários ao ambiente, para que **itens e funcionalidades sejam compartilhados** entre os membros.

Hoje os dados de estoque e lista de compras são atrelados ao `user_id` de forma isolada. Esta evolução introduz o conceito de **ambiente** (multi-tenancy com compartilhamento) e migra o estoque/lista para pertencerem ao ambiente.

## Decisões definidas

- **Dados existentes:** recriar do zero (perder dados atuais — willon, teste@example.com, etc.).
- **Papéis:** Dono (criador) + Membros. Dono gerencia membros e o ambiente; membros só editam itens.
- **Múltiplos ambientes:** sim, um usuário pode participar de vários e alternar entre eles.
- **Convite:** se o e-mail do convidado ainda não tiver conta, a conta é criada automaticamente.
- **Ambiente ativo:** passado via header **`X-Environment-Id`** nas requisições de estoque/compras.
- **Tela pós-login:** auto-selecionar o primeiro ambiente; se não houver nenhum, ir direto para a tela de criar.

---

## 1. Banco de Dados (`backend/db/schema.sql`)

### Novas tabelas

```sql
-- Ambientes (as "Dispensas")
CREATE TABLE environments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Relação usuário <-> ambiente
CREATE TABLE environment_members (
    environment_id UUID NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member',   -- 'owner' | 'member'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (environment_id, user_id)
);
```

- O `owner_id` em `environments` também consta como membro em `environment_members` com `role = 'owner'` (redundância para consulta rápida de dono e para manter a regra uniforme de "todos os membros são acessíveis pela mesma tabela").

### Alterações nas tabelas de estoque

- `pantry_items` e `shopping_list` passam de `user_id` para `environment_id`:
  ```sql
  ALTER TABLE pantry_items ADD COLUMN environment_id UUID NULL;
  ALTER TABLE shopping_list ADD COLUMN environment_id UUID NULL;
  ```
- Unicidade passa a ser `(environment_id, product_id)` em `pantry_items` e `(environment_id, product_id, is_checked)` em `shopping_list`.
- Índices: `idx_pantry_environment ON pantry_items(environment_id)`, `idx_shopping_environment ON shopping_list(environment_id)`, e índices compostos equivalentes aos atuais.

### Catálogo (invariação)

- `products` e `categories` continuam **globais** (catálogo compartilhado). Apenas estoque e lista de compras passam a ser por ambiente.

### Estratégia de execução

Como optamos por recriar do zero (dados atuais serão perdidos), o schema novo será aplicado com `DROP TABLE` (ou recreação) das tabelas envolvidas, seguindo o novo modelo.

---

## 2. Backend (Express)

### Novas rotas — `backend/src/routes/environments.js`

| Rota | Função | Acesso |
|------|--------|--------|
| `GET /api/environments` | Lista ambientes do usuário logado (+ papel e membros) | autenticado |
| `POST /api/environments` | Cria ambiente (`name`); criador vira `owner` | autenticado |
| `PATCH /api/environments/:id` | Renomeia o ambiente | owner |
| `DELETE /api/environments/:id` | Exclui o ambiente | owner |
| `POST /api/environments/:id/members` | Convida por e-mail (`email`); cria usuário se não existir; vincula como `member` | owner |
| `DELETE /api/environments/:id/members/:userId` | Remove membro | owner |
| `PUT /api/environments/:id/members/:userId` | Muda papel (ex.: promover a owner/member) | owner |

### Middleware — `backend/src/middlewares/environment.js`

- `requireAuth` (existente) continua definindo `req.userId`.
- Novo **`requireEnvironment`**: lê o `X-Environment-Id` do header, valida que `req.userId` é membro do ambiente e injeta `req.environmentId` + `req.role`.
- Retorna `403` se o usuário não for membro do ambiente.
- Aplicado **apenas** nas rotas de estoque/compras (pantry, shopping e a parte que usa estoque).

### Ajustes nas rotas existentes

- `pantry.js` e `shopping.js`: trocar `WHERE user_id = $1` → `WHERE environment_id = $1`, usando `req.environmentId` injetado pelo middleware.
- `products.js`: manter o catálogo global; apenas a parte que afeta estoque passa a respeitar o ambiente.
- Montagem em `server.js`: `/api/environments` novo; nas rotas de pantry/shopping passar a exigir o middleware de ambiente.

---

## 3. Frontend (Flutter)

### Contexto de ambiente ativo (Riverpod)

- Novo **`environmentControllerProvider`** (`StateNotifier<EnvironmentState>`):
  - carrega a lista de ambientes do usuário autenticado;
  - `selectEnvironment(envId)` guarda o ambiente ativo, persistido em secure storage (`storageEnvKey`).
- Pós-login: **auto-seleciona o primeiro** ambiente; se não houver, navega direto para a tela de **criar** ambiente.

### Envio do ambiente ativo nas chamadas de API

- `PantryController`, `ShoppingController` (e catálogo quando aplicável) anexam o header **`X-Environment-Id`** nas chamadas, lendo o ambiente ativo via `EnvironmentController`.
- O `ApiClient` (Dio) pode anexar o header automaticamente no interceptor, usando o valor persistido.

### Novos modelos

- `Environment` (id, name, role, ownerId)
- `EnvironmentMember` (userId, name, email, role)

### Novas telas / fluxo

1. **`EnvironmentListScreen`** — lista os ambientes do usuário; botão positivo para **criar** novo ambiente (nome). Ao tocar, entra no ambiente.
2. **`EnvironmentDetailScreen`** — mostra nome e membros; permite **convidar por e-mail** (campo + botão) e **remover membro** (só owner); owner também renomeia/exclui o ambiente.
3. **`HomeScreen`** — após autenticar, exibe o ambiente ativo selecionável (dropdown no `AppBar`) e as abas **Dispensa** e **Compras** operando nesse ambiente.
4. Estado vazio quando não há ambiente selecionado.

### Regras de UI por papel

- **Owner:** vê botões de convidar/remover membros, renomear e excluir o ambiente.
- **Member:** vê e edita os itens, mas não gerencia membros nem o ambiente.

---

## 4. Migração e Verificação

1. Aplicar o novo schema no PostgreSQL (recriando as tabelas que mudam — dados atuais serão perdidos).
2. `flutter analyze` e `flutter test` sem erros.
3. `flutter build web` bem-sucedido.
4. Teste funcional do backend (curl) cobrindo:
   - criar ambiente;
   - convidar um segundo usuário (conta criada automaticamente se não existir);
   - adicionar item como membro;
   - ver o mesmo item acessado por outro membro (compartilhado);
   - remover membro → perde o acesso ao ambiente;
   - acesso negado (403) a non-membro.
5. Teste no app web em `http://localhost:8080` (backend na porta 3007).
