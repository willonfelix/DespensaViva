# Plano: WhatsApp OTP → Email OTP

## Decisões

- Login por telefone → busca email no DB → envia OTP pro email
- Expiração: 5 min (300s)
- Rate limiting: 5 tentativas → bloqueio 1 min
- Troca completa, código WhatsApp mantido comentado para reversão

---

## Etapas

### 1. Instalar dependência

```bash
npm install nodemailer && npm install -D @types/nodemailer
```

### 2. Schema DB — `supabase_schema.sql`

Adicionar colunas na tabela `users`:

```sql
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS tentativas INT DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bloqueado_ate TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users (email);
```

### 3. Criar serviço email — `src/lib/email/smtp-sender.ts` (novo)

- Copiar `EmailSender` do blueprint `email-otp-documentation.md`
- Adaptar `buildHtml()` com branding "Minha Orta" (verde #365902)
- Fallback DEV: loga OTP no console se SMTP não configurado
- Retorno boolean (true = enviado, false = falhou)

### 4. Modificar `src/lib/supabase.ts`

a) `getUserByPhone()` — retornar também campo `email`

b) `updateUserVerificationCode()` — expiração 60000 → 300000 (5 min). Resetar `tentativas = 0`

c) `registerNewUser()` — adicionar parâmetro `email`. Salvar na coluna `email`

d) Criar `getUserEmailByPhone()` — buscar email do user pelo telefone

e) Criar `triggerEmailVerification()` — substituta `triggerWhatsAppVerification()`:
   - Busca email do user
   - Chama `EmailSender.sendOtp(email, codigo, nome)`
   - Retorna boolean
   - **Não deletar** `triggerWhatsAppVerification()` — manter comentada

f) `validateUserOTP()` — adicionar rate limiting:
   - Se `bloqueado_ate > agora()` → retorna 429 BLOCKED
   - Se código errado → incrementa `tentativas`. Se >= 5 → seta `bloqueado_ate = agora() + 1 min`
   - Se código certo → reseta `tentativas = 0`
   - Trocar mensagem "verifique o WhatsApp" → "verifique o e-mail"

### 5. Modificar `src/components/Auth.tsx`

a) Geração OTP segura — trocar `Math.random()` por `crypto.getRandomValues()`

b) Tela Login — texto WhatsApp → e-mail

c) Tela Cadastro — adicionar campo Email (obrigatório). Passar email pra `registerNewUser()`

d) `handleLoginSubmit` — chamar `triggerEmailVerification()`. Timer 300s

e) `handleRegisterSubmit` — idem. Timer 300s

f) `handleResendOTP` — chamar `triggerEmailVerification()`. Timer 300s

g) `handleVerifyOTP` — mensagem erro: "verifique o e-mail"

### 6. Manter código WhatsApp como fallback

- `triggerWhatsAppVerification()` → comentar com `// [RESERVA] WhatsApp fallback`
- Edge Function `supabase/send-verification/index.tsx` → não mexer

### 7. Variáveis de ambiente

- `.env` já tem SMTP ✓
- `.env.example` → adicionar SMTP vars

### 8. Testes — `src/test/Auth.test.tsx`

- Mockar `EmailSender` em vez de Edge Function
- Testar: envio OK, envio falha, OTP expirado, rate limiting, desbloqueio

---

## Arquivos afetados

| Arquivo | Ação |
|---------|------|
| `package.json` | Adicionar nodemailer |
| `src/lib/email/smtp-sender.ts` | **Criar** |
| `src/lib/supabase.ts` | Modificar |
| `src/components/Auth.tsx` | Modificar |
| `supabase_schema.sql` | Adicionar colunas |
| `.env.example` | Adicionar SMTP vars |
| `src/test/Auth.test.tsx` | Atualizar mocks |

---

## Ordem de execução

1. Schema DB (SQL migration)
2. `npm install nodemailer`
3. `src/lib/email/smtp-sender.ts` (criar serviço)
4. `src/lib/supabase.ts` (lookup email, rate limiting, expiração)
5. `src/components/Auth.tsx` (UI, crypto OTP, texto)
6. `.env.example`
7. Testes
8. Testar fluxo completo

---

## Riscos

- **Users existentes sem email** — login vai falhar. Opção: exigir email no primeiro login
- **SMTP Gmail** — pode bloquear se many requests (usar app password)
- **Edge Function WhatsApp** — manter ativa mas sem chamadas = custo zero
