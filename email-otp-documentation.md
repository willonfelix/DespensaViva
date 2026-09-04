# Envio de Código de Autenticação (OTP) via E-mail

Documentação completa do fluxo de envio de OTP por e-mail no projeto **fideliza-api**, para adaptação em outro projeto.

---

## 1. Visão Geral do Fluxo

```
Frontend                    API (Fastify)                 Banco (Prisma)          SMTP
   │                            │                            │                     │
   │  POST /auth/cliente/login  │                            │                     │
   │  { telefone,               │                            │                     │
   │    solicitar_otp: true }   │                            │                     │
   │ ──────────────────────────>│                            │                     │
   │                            │  Invalida OTPs anteriores  │                     │
   │                            │ ──────────────────────────>│                     │
   │                            │  Cria novo OTP no banco    │                     │
   │                            │ ──────────────────────────>│                     │
   │                            │  Monta HTML + envia        │                     │
   │                            │ ─────────────────────────────────────────────────>│
   │                            │  Recebe confirmação        │                     │
   │                            │ <─────────────────────────────────────────────────│
   │  { message: "OTP enviado" }│                            │                     │
   │ <──────────────────────────│                            │                     │
   │                            │                            │                     │
   │  POST /auth/cliente/verify-otp                          │                     │
   │  { telefone, otp: "123456" }                            │                     │
   │ ──────────────────────────>│                            │                     │
   │                            │  Busca OTP válido (não     │                     │
   │                            │  usado, não expirado)      │                     │
   │                            │ ──────────────────────────>│                     │
   │                            │  Compara código            │                     │
   │                            │  Incrementa tentativas     │                     │
   │                            │  ou marca como usado       │                     │
   │                            │ ──────────────────────────>│                     │
   │  { access_token, refresh   │                            │                     │
   │    _token, cliente }       │                            │                     │
   │ <──────────────────────────│                            │                     │
```

---

## 2. Dependência

```bash
npm install nodemailer
npm install -D @types/nodemailer
```

---

## 3. Variáveis de Ambiente (`.env`)

```env
# SMTP - envio de e-mail OTP
SMTP_HOST=smtp.hostinger.com
SMTP_PORT=465
SMTP_USER=seu@email.com.br
SMTP_PASS=sua-senha
SMTP_FROM=noreply@seudominio.com
```

**Comportamento:** Se `SMTP_HOST`, `SMTP_USER` ou `SMTP_PASS` estiverem vazios, o sistema entra em modo DEV — o OTP é impresso no `console.log` sem enviar e-mail.

---

## 4. Schema do Banco (Prisma)

```prisma
model OtpCode {
  id            Int       @id @default(autoincrement())
  telefone      String
  codigo        String
  tentativas    Int       @default(0)
  expira_em     DateTime
  usado_em      DateTime?
  bloqueado_ate DateTime?
  created_at    DateTime  @default(now())

  @@index([telefone, usado_em])
}
```

**Campos-chave:**

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `telefone` | String | Identificador do usuário (troque por `email` se preferir) |
| `codigo` | String | Código OTP de 6 dígitos |
| `tentativas` | Int | Contador de tentativas de verificação (default: 0) |
| `expira_em` | DateTime | Data/hora de expiração do código |
| `usado_em` | DateTime? | NULL = código ainda válido. Preenchido = código já usado |
| `bloqueado_ate` | DateTime? | Data/hora até quando o usuário está bloqueado |

---

## 5. Serviço de E-mail — `EmailSender`

Arquivo: `src/lib/email/smtp-sender.ts`

```typescript
import nodemailer from 'nodemailer'

function createTransport() {
  const host = process.env.SMTP_HOST
  const port = Number(process.env.SMTP_PORT) || 465
  const user = process.env.SMTP_USER
  const pass = process.env.SMTP_PASS

  if (!host || !user || !pass) {
    console.error('[EMAIL] Configuração SMTP incompleta')
    return null
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,       // SSL apenas na porta 465
    auth: { user, pass },
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 10000,
  })
}

function buildHtml(codigo: string, nome: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f4; margin: 0; padding: 0; }
    .container { max-width: 480px; margin: 40px auto; background: #fff; border-radius: 12px; overflow: hidden; }
    .header { background: #2563eb; color: #fff; text-align: center; padding: 32px 24px; }
    .header h1 { margin: 0; font-size: 24px; }
    .body { padding: 32px 24px; text-align: center; }
    .body p { color: #555; font-size: 16px; line-height: 1.5; margin: 0 0 24px; }
    .code { font-size: 36px; font-weight: bold; letter-spacing: 8px;
            color: #2563eb; background: #eff6ff; padding: 16px 24px;
            border-radius: 8px; display: inline-block; }
    .footer { padding: 16px 24px; text-align: center; font-size: 12px;
              color: #999; border-top: 1px solid #eee; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>SEU APP</h1>
    </div>
    <div class="body">
      <p>Ola <strong>${nome}</strong>,</p>
      <p>Seu codigo de acesso e:</p>
      <div class="code">${codigo}</div>
      <p style="margin-top: 24px; font-size: 14px; color: #999;">Valido por 5 minutos.</p>
    </div>
    <div class="footer">
      SEU APP &mdash; Descricao
    </div>
  </div>
</body>
</html>`
}

export class EmailSender {
  async sendOtp(email: string, codigo: string, nome: string): Promise<boolean> {
    const transport = createTransport()
    const from = process.env.SMTP_FROM || process.env.SMTP_USER

    // Sem transport configurado = modo DEV (loga no console)
    if (!transport || !from) {
      console.log(`[DEV] OTP para ${email}: ${codigo}`)
      return false
    }

    try {
      await transport.sendMail({
        from: `"Seu App" <${from}>`,
        to: email,
        subject: 'Seu codigo de acesso',
        html: buildHtml(codigo, nome),
      })
      return true
    } catch (error) {
      console.error(`[EMAIL] Erro ao enviar para ${email}:`, error)
      return false
    }
  }
}
```

### Pontos importantes do `EmailSender`:

- **`secure: port === 465`** — SSL automático na porta 465, TLS na 587
- **Timeouts de 10s** — Evita conexões penduradas
- **Fallback DEV** — Se SMTP não configurado, loga o OTP no console
- **Retorno boolean** — `true` = enviado, `false` = falhou (chamador decide o que fazer)

---

## 6. Lógica OTP no Route Handler

Arquivo: `src/routes/auth.ts`

### Constantes

```typescript
const OTP_EXPIRATION_MIN = 5     // Código expira em 5 minutos
const MAX_TENTATIVAS = 5         // Máximo de 5 tentativas erradas
const BLOQUEIO_MIN = 1           // Bloqueia por 1 minuto após 5 erros
const OTP_LENGTH = 6             // Código tem 6 dígitos
const OTP_MIN = 10 ** (OTP_LENGTH - 1)  // 100000
const OTP_MAX = 10 ** OTP_LENGTH - 1    // 999999
```

### Geração do OTP

```typescript
import crypto from 'crypto'

function gerarOtp(): string {
  return crypto.randomInt(OTP_MIN, OTP_MAX).toString()
}
```

Usa `crypto.randomInt()` para números cryptograficamente seguros.

### Assistente de tempo

```typescript
function agora() { return new Date() }

function expiraEm() {
  return new Date(Date.now() + OTP_EXPIRATION_MIN * 60 * 1000)
}

function daquiAminutos(min: number) {
  return new Date(Date.now() + min * 60 * 1000)
}
```

---

## 7. Endpoint: Solicitar OTP (Login)

`POST /auth/cliente/login` com `{ telefone, solicitar_otp: true }`

```typescript
// 1. Invalidar OTPs anteriores não usados do mesmo telefone
await db.otpCode.updateMany({
  where: { telefone, usado_em: null },
  data: { usado_em: agora() },
})

// 2. Gerar novo código
const codigo = gerarOtp()

// 3. Salvar no banco
await db.otpCode.create({
  data: { telefone, codigo, expira_em: expiraEm() },
})

// 4. Enviar por e-mail (se cliente tem email cadastrado)
if (cliente.email) {
  await emailSender.sendOtp(cliente.email, codigo, cliente.nome)
}

return reply.send({ message: 'OTP enviado', telefone })
```

---

## 8. Endpoint: Verificar OTP

`POST /auth/cliente/verify-otp` com `{ telefone, otp }`

```typescript
// 1. Buscar OTP válido mais recente
const record = await db.otpCode.findFirst({
  where: { telefone, usado_em: null, expira_em: { gt: agora() } },
  orderBy: { created_at: 'desc' },
})

if (!record) {
  return reply.status(400).send({ code: 'INVALID_OTP', message: 'Codigo invalido ou expirado' })
}

// 2. Verificar bloqueio
if (record.bloqueado_ate && record.bloqueado_ate > agora()) {
  return reply.status(429).send({ code: 'BLOCKED', message: 'Muitas tentativas. Aguarde 1 minuto.' })
}

// 3. Comparar código
if (record.codigo !== otp) {
  const novasTentativas = record.tentativas + 1
  const updateData = { tentativas: novasTentativas }

  // Bloquear após MAX_TENTATIVAS erros
  if (novasTentativas >= MAX_TENTATIVAS) {
    updateData.bloqueado_ate = daquiAminutos(BLOQUEIO_MIN)
  }

  await db.otpCode.update({ where: { id: record.id }, data: updateData })

  return reply.status(400).send({
    code: 'INVALID_OTP',
    message: novasTentativas >= MAX_TENTATIVAS
      ? 'Codigo invalido. Muitas tentativas. Aguarde 1 minuto.'
      : `Codigo invalido. Restam ${MAX_TENTATIVAS - novasTentativas} tentativa(s).`,
  })
}

// 4. Código correto — marcar como usado
await db.otpCode.update({
  where: { id: record.id },
  data: { usado_em: agora() },
})

// 5. Gerar tokens de sessão (JWT + refresh token)
const token = app.jwt.sign({ id: cliente.id, role: 'cliente' }, { expiresIn: '1h' })

return reply.send({ access_token: token, cliente: { ... } })
```

---

## 9. Integração no Register

`POST /auth/cliente/register` — cria OTP junto com o cadastro:

```typescript
// 1. Invalidar OTPs anteriores
await db.otpCode.updateMany({
  where: { telefone, usado_em: null },
  data: { usado_em: agora() },
})

// 2. Gerar e salvar OTP
const codigo = gerarOtp()
await db.otpCode.create({
  data: { telefone, codigo, expira_em: expiraEm() },
})

// 3. Upsert do cliente
await db.cliente.upsert({
  where: { telefone },
  create: { nome, telefone, email: email || null, lgpd_aceite: true },
  update: { nome, email: email || null, lgpd_aceite: true },
})

// 4. Enviar OTP por e-mail
let emailEnviado = true
if (email) {
  emailEnviado = await emailSender.sendOtp(email, codigo, nome)
}

// 5. Em DEV, incluir OTP na resposta
const response = {
  message: emailEnviado ? 'OTP enviado' : 'OTP criado, mas envio falhou',
  email_enviado: emailEnviado,
}
if (process.env.NODE_ENV !== 'production' && !emailEnviado) {
  response.otp_debug = codigo  // Mostra OTP no response (só em DEV)
}
```

---

## 10. Segurança — Resumo

| Mecanismo | Detalhe |
|-----------|---------|
| Geração | `crypto.randomInt()` (CSPRNG) |
| Expiração | 5 minutos (configurável) |
| Tentativas | Máximo 5 antes de bloquear |
| Bloqueio | 1 minuto após 5 erros |
| Invalidação | OTPs anteriores são marcados como usados ao solicitar novo |
| Busca | Sempre pega o OTP mais recente não usado |
| Senha | OTP nunca retorna na resposta em produção |

---

## 11. Adaptação para Outro Projeto

### Checklist

1. **Instalar dependência:**
   ```bash
   npm install nodemailer
   npm install -D @types/nodemailer
   ```

2. **Criar tabela `OtpCode`** no schema do banco — copie o model Prisma acima

3. **Criar variáveis de ambiente** `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM`

4. **Copiar o serviço `EmailSender`** em `src/lib/email/smtp-sender.ts`
   - Ajuste o `buildHtml()` com a marca/cor do novo projeto
   - Ajuste o `from` no `sendMail()`

5. **Implementar as rotas** adaptando:
   - Geração do OTP (`crypto.randomInt`)
   - Criação no banco
   - Envio via `emailSender.sendOtp()`
   - Verificação com lógica de tentativas e bloqueio
   - Invalidação de OTPs anteriores

6. **Ajustar o campo identificador** — se usar `email` em vez de `telefone`, mude o campo na tabela e nas queries

7. **Opcional: unificar request** — O fideliza usa dois passos separados (solicitar → verificar). Pode unificar em um só request que faz ambos, ou manter separado para UX de "código enviado"

### Arquivos para criar/copiar

| Arquivo | Origem |
|---------|--------|
| `src/lib/email/smtp-sender.ts` | Copiar e adaptar branding |
| Prisma schema `OtpCode` | Copiar model |
| Route handler OTP | Adaptar lógica de `src/routes/auth.ts` |

---

## 12. SMTP — Portas e Configuração

| Provedor | Host | Porta | SSL/TLS |
|----------|------|-------|---------|
| Hostinger | smtp.hostinger.com | 465 | SSL |
| Hostinger | smtp.hostinger.com | 587 | TLS |
| Gmail | smtp.gmail.com | 465 | SSL |
| Gmail | smtp.gmail.com | 587 | TLS |
| Outlook | smtp.office365.com | 587 | TLS |

**Gmail:** usar senha de app (não senha normal da conta).
