# Plano: Lembrar Senha com OTP via E-mail (Gmail SMTP)

## Decisões

- **SMTP**: Gmail (`smtp.gmail.com`, porta 465 SSL). Credenciais já preenchidas no `.env` raiz (`programa.fideliza.qr@gmail.com` + App Password).
- **Fluxo**: 2 passos (1º e-mail → envia OTP; 2º OTP + nova senha → redefine).
- **Segurança**: resposta genérica no forgot (não revela se o e-mail está cadastrado).
- **Identificador**: `users.email` (já existe, UNIQUE NOT NULL).
- **Expiração**: 5 min · **Rate limit**: 5 tentativas → bloqueio 1 min.
- **Problema de deploy encontrado**: o `docker-compose.yml` NÃO injeta as vars `SMTP_*` no service `backend` (só PORT/DATABASE_URL/JWT_*), e o `.env` raiz não é copiado/montado na imagem. **Correção no compose é obrigatória** para o envio real funcionar no container.

---

## Etapas

### 1. Migração `backend/db/migrations/002_add_otp.sql` (novo)

Aplicada automaticamente no startup pelo `runMigrations()` (tabela `schema_migrations`).

```sql
CREATE TABLE IF NOT EXISTS otp_codes (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    codigo VARCHAR(6) NOT NULL,
    tentativas INT NOT NULL DEFAULT 0,
    expira_em TIMESTAMPTZ NOT NULL,
    usado_em TIMESTAMPTZ,
    bloqueado_ate TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_otp_email ON otp_codes(email);
```

### 2. Dependência `nodemailer`

Adicionar ao `backend/package.json` e instalar via `npm install nodemailer` (rebuild no Docker).

### 3. Serviço de e-mail `backend/src/lib/email/emailSender.js` (novo)

- Transporter Gmail: `host: SMTP_HOST`, `port: SMTP_PORT`, `secure: port === 465` (SSL na 465).
- Lê `SMTP_HOST/SMTP_PORT/SMTP_USER/SMTP_PASS/SMTP_FROM` do `process.env`.
- Sem config → **modo DEV**: `console.log('[DEV] OTP para {email}: {codigo}')`, retorna `false`.
- `sendOtp(email, codigo, nome)` com HTML branding DespensaViva; timeouts 10s; retorno boolean (`true` = enviado, `false` = falhou).

### 4. Rotas em `backend/src/routes/auth.js`

**`POST /auth/forgot-password`** `{ email }`
- Normaliza email. Resposta **sempre genérica 200**: `{ message: 'Se o e-mail estiver cadastrado, enviaremos um código.' }` (não informa existência).
- Se o user existe:
  - Invalida OTPs anteriores não-usados do email (marca `usado_em`).
  - Gera `crypto.randomInt(100000, 1000000).toString()` (6 dígitos CSPRNG).
  - Salva OTP (expira em 5 min).
  - `emailSender.sendOtp(email, codigo, nome)` — nunca expõe o código na resposta (só log DEV).

**`POST /auth/reset-password`** `{ email, otp, new_password }`
- Busca OTP válido mais recente: `usado_em IS NULL AND expira_em > now()`, `ORDER BY created_at DESC`.
- Se `bloqueado_ate > now()` → `429 BLOCKED` 'Muitas tentativas. Aguarde 1 minuto.'
- Código errado → `tentativas++`; se `>= 5` seta `bloqueado_ate = now() + 1 min`; retorna erro 'Código inválido. Restam X tentativa(s).'
- Código certo → marca `usado_em`; valida `new_password >= 6`; `bcrypt.hash` + `UPDATE users SET password_hash`; retorna sucesso.

### 5. Fix deploy — `docker-compose.yml`

Adicionar no service `backend.environment` (lendo do `.env` raiz):
```yaml
SMTP_HOST: ${SMTP_HOST}
SMTP_PORT: ${SMTP_PORT}
SMTP_USER: ${SMTP_USER}
SMTP_PASS: ${SMTP_PASS}
SMTP_FROM: ${SMTP_FROM}
```

### 6. Frontend Flutter

**`app/lib/features/auth/auth_controller.dart`**
- `forgotPassword(email)` → POST `/auth/forgot-password`.
- `resetPassword(email, otp, newPassword)` → POST `/auth/reset-password`.

**`app/lib/features/auth/auth_screen.dart`**
- Link "Esqueceu a senha?" na tela de login.
- Passo 1: tela e-mail → envia OTP → mostra mensagem genérica.
- Passo 2: campo OTP (6 dígitos) + nova senha → confirma → snackbar sucesso → volta ao login.
- Validações: formato e-mail, senha >= 6, OTP 6 dígitos.

---

## Arquivos afetados

| Arquivo | Ação |
|---------|------|
| `backend/package.json` | Adicionar `nodemailer` |
| `backend/db/migrations/002_add_otp.sql` | **Criar** |
| `backend/src/lib/email/emailSender.js` | **Criar** |
| `backend/src/routes/auth.js` | Modificar (2 rotas) |
| `docker-compose.yml` | Mapear vars SMTP no backend |
| `app/lib/features/auth/auth_controller.dart` | Modificar |
| `app/lib/features/auth/auth_screen.dart` | Modificar (UI lembrar senha) |

---

## Ordem de execução

1. Migration SQL (`002_add_otp.sql`).
2. `npm install nodemailer` no backend.
3. Criar `emailSender.js`.
4. Rotas `forgot-password` / `reset-password` em `auth.js`.
5. `docker-compose.yml` — mapear `SMTP_*`.
6. Frontend: controller + telas.
7. Build backend → up → conferir migração `002` no log.
8. Test E2E: forgot → pegar OTP do e-mail real (Gmail) → reset → login com nova senha.
9. Build web → up.

---

## Testes

- **E2E via container**: forgot (log/mail mostra OTP) → reset com OTP → login com nova senha.
- **Envio real**: criar usuário de teste, chamar forgot, verificar chegada do e-mail no Gmail.

## Riscos

- **Compose sem SMTP injetado** → envio falha no container (corrigir no passo 5).
- **Gmail sem App Password** → bloco de envio; já preenchida no `.env`.
- **Rate limit Gmail** em envios em massa → ok para uso leve.
- **XSS no HTML do e-mail** → escapar nome (vem do banco).
- **Enumeração de e-mail** → mitigada pela resposta genérica.

## Reversão

- Migração aplicada fica rastreada em `schema_migrations`; para reverter, `DROP TABLE otp_codes;` + deletar linha da migration.
- Rotas novas não afetam fluxos existentes (login/register intactos).
