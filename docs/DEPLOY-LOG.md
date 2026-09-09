# Log de Deploy — DespensaViva

Data: 2026-09-03

## Problema
`https://despensa.wikicode.com.br` retornava erro 502 e a página não carregava.

## Diagnóstico
Investigando os logs dos containers:

1. **`cloudflared-wikicode-despensa`**:
   - O ingress do Cloudflare apontava para `http://localhost:3007`.
   - Com `network_mode: service:caddy`, o tunnel compartilha o namespace de rede do caddy.
   - Dentro desse namespace, `localhost:3007` tentava alcançar o backend, mas o backend está em outra rede bridge (hostname `backend`, não `localhost`).
   - Resultado: `dial tcp [::1]:3007: connect: connection refused`.

2. **`despensaviva_caddy`**:
   - O Caddy escutava na porta `:80`, não em `:3007`.
   - As tentativas de emitir certificado HTTPS via ACME falhavam porque o Cloudflare devolvia 502 (o tunnel não alcançava a origem).

3. **Container não recriado**: após editar o `Caddyfile`, o container do Caddy continuava escutando `:80` — `docker compose up -d` não recria containers quando o YAML não muda. Precisou `--force-recreate`.

## Solução
1. **Caddy escuta na porta do ingress do Cloudflare** — alterado em `docker/Caddyfile`:
   - Antes: `:80 { ... }`
   - Depois: `:3007 { ... }`
   - O Caddy roteia `/api/*` → `backend:3007` (via bridge, resolve hostname) e o resto → `web:80`.

2. **Recriar containers para aplicar**:
   ```bash
   docker compose up -d --force-recreate caddy
   docker compose up -d --force-recreate tunnel
   ```
   O tunnel precisa ser recriado porque usa `network_mode: service:caddy` e deve re-sincronizar com o novo container do Caddy.

3. **Resolução de DNS transitória**: o erro `lookup cfd-features.argotunnel.com on 127.0.0.11:53: server misbehaving` ocorria no cold start mas se resolvia em segundos; não exigiu ação.

## Resultado
- `https://despensa.wikicode.com.br` → carrega o app (título "DespensaViva").
- `https://despensa.wikicode.com.br/api/health` → `{"status":"ok",...}`.
- Tunnel registrou 4 conexões com o Cloudflare.

## Lembrete futuro
- Sempre rodar `--force-recreate` após alterar `Caddyfile` (ou qualquer config montada via volume) para o container reindicar a config.
- O ingress do Cloudflare fixa `localhost:3007`; o gateway (Caddy) deve escutar nessa porta dentro do namespace compartilhado do tunnel.

---

# Deploy 2026-09-04 — "build não subiu a última versão"

## Problema
Após deploy, novas funcionalidades (barcode, perfil, auditoria, sugestões, confirmação de pendências) não apareciam em produção.

## Diagnóstico
Containers/imagens constavam o build novo, MAS o Cloudflare edge servia build antigo:
- `cf-cache-status: HIT`, `Age: 95135` (~26h), `last-modified: 03/09` no `main.dart.js` público.
- Causa: `main.dart.js` e `flutter_bootstrap.js` têm URL FIXA (sem hash). `docker/nginx.conf` antigo marcava **todo** `*.js` como `immutable, max-age=31536000` → CDN/navegador envenenam por 1 ano.
- 404 no barcode no deploy anterior era da própria Open Food Facts (código não existe lá); rota funciona (testado com 3017620422003 → Nutella).

## Correção
1. **`docker/nginx.conf`**: `no-cache` para entrypoints (`main.dart.js`, `flutter_bootstrap.js`, `flutter.js`, `flutter_service_worker.js`, `index.html`, `manifest.json`, `version.json`); `immutable` só para `/assets/` e `/canvaskit/` (hasheados pelo Flutter).
2. **`Dockerfile.web`**: após `flutter build`, `sed` injeta `?v=<build-id>` em `main.dart.js` (no bootstrap) e `flutter_bootstrap.js` (no index) → URL nova a cada build quebra cache do CDN sem precisar purgar.
3. Redeploy: `docker compose build web` + `docker compose up -d --force-recreate web`.

## Verificação
- Índice público referencia `flutter_bootstrap.js?v=be9303...`.
- `main.dart.js?v=…` público: 3.267.264 bytes (== container), contém features `barcode`/`Barcode`.
- Teste funcional API: 21/21 (register, login, env multi-tenant, pantry add, stage/confirm pendência, auditoria, perfil troca senha, gemini key, sugestões no-key 400, barcode, delete, web via Caddy).

## Lembrete
- URL antiga `main.dart.js` sem `?v=` fica no edge por 1 ano (órfã — irrelevante). Purga manual no dashboard é opcional.
- `já está no git? não`: alterações em `docker/nginx.conf`, `Dockerfile.web`, `docs/DEPLOY-LOG.md`.
