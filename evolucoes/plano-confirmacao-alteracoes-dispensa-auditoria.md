# Plano: Confirmação de Alterações na Dispensa + Auditoria

## Decisões

- **Pendência no banco**: tabela `pending_quantity_changes` (sobrevive reload, multi-dispositivo).
- **Escopo auditoria**: dispensa (quantidade aprovada, add, delete) + login.
- **O que fica pendente**: somente incrementar/decrementar quantidade. Add e delete continuam imediatos (mas auditados).
- **Confirmação**: na tela Perfil (card "Alterações pendentes") → transação aplica + audita + limpa.

## Fluxo

1. Tela Dispensa: `+`/`−` → POST `/api/pantry/:id/stage` → grava pendência (upsert por user+item). Badge "pendente" no item/count.
2. Tela Perfil: GET `/api/pantry/pending` → lista itens (atual → novo). Botão **Confirmar alterações**.
3. POST `/api/pantry/confirm` → transação: aplica quantidades, `syncShoppingList`, INSERT `audit_logs`, limpa pendências.
4. Tela Perfil: card "Histórico" → GET `/api/audit` lista operações aprovadas.

---

## Etapas

### 1. Migration `backend/db/migrations/003_add_pending_and_audit.sql` (novo)

```sql
CREATE TABLE IF NOT EXISTS pending_quantity_changes (
    id BIGSERIAL PRIMARY KEY,
    environment_id UUID NOT NULL REFERENCES environments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pantry_item_id INT NOT NULL REFERENCES pantry_items(id) ON DELETE CASCADE,
    new_quantity DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, pantry_item_id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    environment_id UUID REFERENCES environments(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,     -- auth.login | pantry.quantity_change | pantry.add | pantry.delete
    entity VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50),
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pending_env_user ON pending_quantity_changes(environment_id, user_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_env ON audit_logs(environment_id, created_at DESC);
```

### 2. `backend/src/routes/pantry.js`

- `POST /api/pantry/:id/stage` `{ quantity }` — upsert pendência (ON CONFLICT `(user_id, pantry_item_id)` DO UPDATE). Se nova qty == atual → remove pendência (no-op).
- `GET /api/pantry/pending` — pendências do user+ambiente ativo (join products: nome, unidade, qty atual, nova qty).
- `POST /api/pantry/confirm` — transação: lê qty atual, UPDATE `pantry_items.quantity`, `syncShoppingList`, INSERT `audit_logs`, DELETE pendência.
- `POST /api/pantry` — INSERT audit `pantry.add`.
- `DELETE /api/pantry/:id` — INSERT audit `pantry.delete`.
- `DELETE /api/pantry/pending/:id` — cancela 1 pendência.

### 3. `backend/src/routes/audit.js` (novo) + `server.js`

- `GET /api/audit` — últimos logs do user (`ORDER BY created_at DESC`, limite 50).
- Montar em `server.js`: `app.use('/api/audit', auditRoutes);`

### 4. `backend/src/routes/auth.js`

- Login bem-sucedido → INSERT audit `auth.login`.

### 5. Frontend

- `app/lib/models/pending_change.dart` (novo) — pantryItemId, name, unitOfMeasure, currentQuantity, newQuantity.
- `app/lib/models/audit_entry.dart` (novo) — action, entity, entityId, details, createdAt.
- `pantry_controller.dart` — `load()` busca `/pantry` + `/pantry/pending`; `increment`/`decrement` → POST `/pantry/:id/stage`; `confirmPending()` → POST `/pantry/confirm`; `cancelPending(id)`.
- `profile_screen.dart` + `profile_controller.dart` — card "Alterações pendentes" (lista + Confirmar) + card "Histórico de auditoria" (GET `/api/audit`).
- Badge count pendências no header da Dispensa.

---

## Arquivos afetados

| Arquivo | Ação |
|---------|------|
| `backend/db/migrations/003_add_pending_and_audit.sql` | **Criar** |
| `backend/src/routes/pantry.js` | Modificar (stage/pending/confirm + audit add/delete) |
| `backend/src/routes/audit.js` | **Criar** |
| `backend/src/server.js` | Montar `/api/audit` |
| `backend/src/routes/auth.js` | Audit login |
| `app/lib/models/pending_change.dart` | **Criar** |
| `app/lib/models/audit_entry.dart` | **Criar** |
| `app/lib/features/pantry/pantry_controller.dart` | Modificar |
| `app/lib/features/pantry/pantry_screen.dart` | Badge pendentes |
| `app/lib/features/profile/profile_controller.dart` | Modificar |
| `app/lib/features/profile/profile_screen.dart` | Modificar (cards) |

---

## Ordem de execução

1. Migration SQL.
2. Rotas backend (pantry + audit + auth + server).
3. Rebuild backend → up → conferir migração `003` no log.
4. Test E2E via container (stage → pending → confirm → audit).
5. Frontend (models, controller, telas).
6. Build web → up.

## Testes

- E2E: login (audit), add item (audit), stage qty, GET pending, confirm, verificar qty + audit, delete item (audit), GET /api/audit.
- Duplo stage (UNIQUE), cancel pendência, qty == atual (no-op).

## Riscos

- Pendência por user: `UNIQUE (user_id, pantry_item_id)` — cada membro confirma a própria.
- Conflito multi-membro: confirm aplica sobre qty atual lida no momento (old = atual no commit).
- `syncShoppingList` reutilizada no confirm (sem duplicar lógica).