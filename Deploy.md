# Deploy — DespensaViva (Docker + HTTPS via Caddy)

> **ATUALIZADO (03/09/2026):** incluída a camada **Caddy** para HTTPS automático (Let's Encrypt) e configuração **PWA**. O fluxo de proxy `/api` agora é feito pelo Caddy (antes era só o Nginx).

## Arquivos de deploy
- `Dockerfile.web` — compila o Flutter web (multi-stage) e serve com Nginx.
- `Dockerfile.backend` — roda a API Node.js (porta 3007).
- `docker-compose.yml` — orquestra 4 serviços: `db`, `backend`, `web`, `caddy`.
- `docker/nginx.conf` — Nginx serve os estáticos do Flutter (com cache/cache-control apropriado p/ PWA).
- `docker/Caddyfile` — Caddy: HTTPS automático + faz proxy `/api` → backend.
- `.env.example` — variáveis de ambiente de produção (`DOMAIN`, `WEB_PORT`, Postgres, `JWT_SECRET`).
- `.dockerignore` — mantém o contexto do build limpo.

## Arquitetura (mesmo domínio via Caddy)
```
Navegador
   │
   ▼ https://despensa.wikicode.com.br
   Caddy (80/443, TLS automático)  ── domínio: despensa.wikicode.com.br
   ├── /api/*  ──proxy──▶ backend:3007 (Node) ──▶ db (Postgres)
   └── (demais) ──proxy──▶ web:80 (Nginx serve estáticos do Flutter)
```
- O build de produção usa `--dart-define=API_URL=/api` (caminho relativo) → o app chama a API no **mesmo domínio** via proxy, sem CORS. Dev local continua `localhost:3007`.

## Como rodar (num servidor com Docker + Compose)
```bash
# 1. Copie e ajuste as variáveis (TROQUE JWT_SECRET e a senha do Postgres!)
cp .env.example .env

# 2. Edite .env: defina DOMAIN (ex.: despensa.wikicode.com.br), JWT_SECRET forte, senha do Postgres

# 3. Suba tudo
docker compose up -d --build

# 4. Acesse
# https://despensa.wikicode.com.br   (DNS deve apontar para este servidor)
```

## Observações importantes
1. **DNS:** aponte `despensa.wikicode.com.br` (A/AAAA) para o servidor antes de subir o Caddy; o Caddy emite o certificado Let's Encrypt automaticamente. Portas 80 e 443 devem estar liberadas no firewall.
2. **Certificado:** na primeira subida, o Caddy pede o certificado. Se o domínio ainda não apontar, o TLS pode falhar até o DNS resolver.
3. **Banco:** na primeira subida, o Postgres aplica `backend/db/schema.sql` automaticamente (volume `pgdata`). Os dados persistem entre reinícios.
4. **Produção:** TROQUE `JWT_SECRET` e a senha do Postgres no `.env` (os padrões no `.env.example` são inseguros).
5. **PWA:** o `nginx.conf` trata `flutter_service_worker.js`, `index.html`, `manifest.json` e `version.json` com `no-cache`, e `*.js|wasm|css` com cache imutável, para o service worker e o app instalável funcionarem corretamente.
6. **Docker não está instalado na máquina local** (comando `docker` não reconhecido). Para testar o compose localmente, instale Docker Desktop ou use um servidor (VPS, AWS, etc.).
7. O build do `Dockerfile.web` baixa uma imagem grande do Flutter SDK na primeira vez (~2-4 GB). Pode demorar.

## Alternativa sem Docker
Como o front é estático (`app/build/web`), dá para servir com qualquer servidor web (NGINX/Apache/`serve_web.js`) e rodar o backend Node em separado, com o proxy configurado. Mas o Docker + Caddy é mais simples de manter e já dá HTTPS.
