# Plano: Relatório de Itens do Estoque

**Data:** 16/11/2026
**Status:** Implementado

---

## Visão Geral

Adicionar a geração de um relatório PDF com os itens do estoque de cada Dispensa. Na tela **Minhas Dispensas**, cada Dispensa da lista terá um botão **Relatório**. Ao acioná-lo, o usuário poderá visualizar e compartilhar o PDF daquela Dispensa.

**Objetivo:** facilitar a consulta e o compartilhamento do inventário atualizado de cada Dispensa.

---

## Decisões de Design

| Tópico | Decisão |
|---|---|
| Formato | PDF |
| Acesso | Botão “Relatório” em cada Dispensa na tela “Minhas Dispensas” |
| Conteúdo | Itens cadastrados no estoque, sem incluir a lista de compras |
| Geração | No aplicativo, a partir dos dados retornados pela API |
| Visualização e compartilhamento | Preview/compartilhamento do PDF usando o pacote `printing` |
| Dispensa ativa | Gerar o relatório da Dispensa escolhida sem alterar a Dispensa ativa do usuário |

---

## 1. API — dados do relatório por Dispensa

**Editar:** `backend/src/routes/environments.js`

**Criar rota:** `GET /api/environments/:id/report`

- Exigir autenticação (`requireAuth`).
- Confirmar que o usuário é membro da Dispensa solicitada; negar acesso se não for.
- Consultar somente os itens associados ao `environment_id` da rota, incluindo nome do produto, categoria, quantidade, unidade de medida, quantidade mínima e validade.
- Ordenar os itens pelo nome do produto.
- Retornar JSON com nome da Dispensa, data/hora de geração e itens. A rota não deve depender da Dispensa ativa enviada no cabeçalho `X-Environment-Id`.
- Preservar os retornos de erro existentes para acesso negado e falhas no servidor.

**Formato sugerido:**
```json
{
  "environment": { "id": "…", "name": "Despensa principal" },
  "generatedAt": "2026-11-16T20:38:00.000Z",
  "items": [
    {
      "name": "Arroz",
      "category": "Grãos",
      "quantity": 2,
      "unitOfMeasure": "kg",
      "minQuantity": 1,
      "expirationDate": null
    }
  ]
}
```

---

## 2. Frontend — botão na tela “Minhas Dispensas”

**Editar:** `app/lib/features/environment/environment_list_screen.dart`

- Manter o toque no cartão/linha da Dispensa para selecioná-la como hoje.
- Adicionar em cada cartão um botão com o texto **Relatório**, sem substituir a ação atual de seleção.
- Ao tocar no botão, iniciar a geração usando o ID da Dispensa daquela linha.
- Mostrar indicador de carregamento e impedir acionamentos repetidos enquanto o relatório daquela Dispensa estiver sendo preparado.
- Em caso de erro, informar o usuário com mensagem visível e permitir uma nova tentativa.

---

## 3. Frontend — geração, visualização e compartilhamento do PDF

**Criar:**
- `app/lib/features/report/stock_report_service.dart`
- `app/lib/features/report/stock_report_screen.dart`

**Editar:** `app/pubspec.yaml`

- Adicionar as dependências `pdf` e `printing`.
- O serviço solicita os dados da rota usando o ID da Dispensa selecionada e monta o PDF.
- O documento deve apresentar:
  - título “Relatório de Itens do Estoque”;
  - nome da Dispensa e data/hora de geração;
  - total de itens;
  - tabela ordenada por nome com produto, categoria, quantidade/unidade, quantidade mínima e validade.
- Datas ausentes devem aparecer como “Não informada”; categoria ausente, como “Sem categoria”.
- Quando não houver itens, gerar um PDF válido com uma mensagem informando que o estoque está vazio.
- Abrir a visualização do PDF com ações para compartilhar e imprimir/salvar, conforme suporte da plataforma.

---

## 4. Testes e critérios de aceite

- A tela mostra o botão **Relatório** para cada Dispensa, sem remover a seleção atual pelo cartão.
- Gerar o relatório de uma Dispensa diferente da ativa não altera a Dispensa ativa nem mistura os estoques.
- Um membro autorizado recebe somente os itens da Dispensa informada; um usuário sem acesso não consegue obter seus dados.
- O PDF exibe corretamente identificação da Dispensa, horário, total e dados dos itens, incluindo categoria ou validade ausentes.
- Uma Dispensa sem itens produz um PDF válido com a mensagem de estoque vazio.
- Falhas na consulta ou na geração são comunicadas ao usuário, sem apresentar o fluxo como concluído.

---

## 5. Index de arquivos afetados

| Arquivo | Ação |
|---|---|
| `backend/src/routes/environments.js` | editar (rota de dados do relatório por Dispensa) |
| `app/lib/features/environment/environment_list_screen.dart` | editar (botão “Relatório” em cada Dispensa) |
| `app/lib/features/report/stock_report_service.dart` | criar (consulta e geração do PDF) |
| `app/lib/features/report/stock_report_screen.dart` | criar (visualização e ações do PDF) |
| `app/test/features/report/stock_report_service_test.dart` | criar (PDF vazio, campos opcionais e erros de acesso) |
| `app/pubspec.yaml` | editar (dependências `pdf` e `printing`) |

---

## Segurança e observações

- A API deve validar a associação do usuário à Dispensa indicada no caminho, mesmo que a interface liste somente dispensas acessíveis.
- A consulta deve filtrar pelo ID da Dispensa solicitado para evitar exposição de itens de outros estoques.
- O relatório contém apenas dados necessários ao inventário e é gerado sob demanda; não será armazenado no backend.
