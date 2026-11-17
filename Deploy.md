# Deploy — DespensaViva (Docker + Cloudflare Tunnel)

> O HTTPS público é fornecido pelo Cloudflare Tunnel. Caddy faz o proxy interno para o backend e o frontend.

## Arquivos de deploy
- `Dockerfile.web` — compila o Flutter web (multi-stage) e serve com Nginx.
- `Dockerfile.backend` — roda a API Node.js (porta 3007).
- `docker-compose.yml` — orquestra `db`, `backend`, `web`, `caddy` e `tunnel`.
- `Dockerfile.caddy` — inclui a configuração do proxy na imagem, sem bind mount de arquivo.
- `docker/nginx.conf` — Nginx serve os estáticos do Flutter (com cache/cache-control apropriado p/ PWA).
- `docker/Caddyfile` — Caddy: HTTPS automático + faz proxy `/api` → backend.
- `.env.example` — variáveis de ambiente de produção (`DOMAIN`, `WEB_PORT`, Postgres, `JWT_SECRET`).
- `.dockerignore` — mantém o contexto do build limpo.

## Arquitetura (mesmo domínio via Caddy)
```
Navegador
   │
   ▼ https://despensa.wikicode.com.br
   Cloudflare Tunnel (TLS público)
   └── Caddy (:3007, proxy interno)
   ├── /api/*  ──proxy──▶ backend:3007 (Node) ──▶ db (Postgres)
   └── (demais) ──proxy──▶ web:80 (Nginx serve estáticos do Flutter)
```
- O build de produção usa `--dart-define=API_URL=/api` (caminho relativo) → o app chama a API no **mesmo domínio** via proxy, sem CORS. Dev local continua `localhost:3007`.

## Como rodar (num servidor com Docker + Compose)
```bash
# 1. Copie e ajuste as variáveis (TROQUE JWT_SECRET e a senha do Postgres!)
cp .env.example .env

# 2. Edite .env: defina DOMAIN, JWT_SECRET forte, senha do Postgres e
#    CLOUDFLARE_TUNNEL_TOKEN obtido no painel Cloudflare.

# 3. Suba tudo
docker compose up -d --build

# 4. Acesse
# https://despensa.wikicode.com.br   (DNS deve apontar para este servidor)
```

## Observações importantes
1. **Cloudflare Tunnel:** configure a rota pública do tunnel para `http://localhost:3007`. O `cloudflared` compartilha a rede do Caddy, que encaminha `/api` ao backend e as demais rotas ao Nginx.
2. **Credenciais:** não armazene o token do tunnel no Compose nem no Git. Se ele já foi exposto, revogue-o no painel Cloudflare e substitua o valor no `.env`.
3. **Banco:** na primeira subida, o Postgres aplica `backend/db/schema.sql` automaticamente (volume `pgdata`). Os dados persistem entre reinícios.
4. **Produção:** TROQUE `JWT_SECRET` e a senha do Postgres no `.env` (os padrões no `.env.example` são inseguros).
5. **PWA:** o `nginx.conf` trata `flutter_service_worker.js`, `index.html`, `manifest.json` e `version.json` com `no-cache`, e `*.js|wasm|css` com cache imutável, para o service worker e o app instalável funcionarem corretamente.
6. O build do `Dockerfile.web` baixa uma imagem grande do Flutter SDK na primeira vez (~2-4 GB). Pode demorar.

## Alternativa sem Docker
Como o front é estático (`app/build/web`), dá para servir com qualquer servidor web (NGINX/Apache/`serve_web.js`) e rodar o backend Node em separado, com o proxy configurado. Mas o Docker + Caddy é mais simples de manter e já dá HTTPS.
