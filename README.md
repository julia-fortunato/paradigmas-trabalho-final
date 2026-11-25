# Puppies em Prolog + Elm

Jogo de lógica inspirado em *Queens / Star Battle* com temática de álbum de figurinhas de cachorrinhos. O **Prolog** gera tabuleiros com solução única, verifica conflitos, dá dicas por prova de obrigatoriedade e resolve o puzzle; o **Elm** cuida da interface, navegação por teclado e estado do jogo; o **Python** faz apenas a ponte HTTP entre os dois.

```text
┌──────────────────────┐   HTTP/JSON   ┌───────────────────┐  janus / swipl  ┌──────────────────┐
│ Navegador            │ ────────────▶ │ FastAPI (Python)  │ ──────────────▶ │ SWI-Prolog       │
│ Elm + CSS (Vite)     │ ◀──────────── │ backend/app/      │ ◀────────────── │ backend/prolog/  │
└──────────────────────┘               └───────────────────┘                 └──────────────────┘
    avaliado                              NÃO avaliado                           avaliado
```

## Regras do jogo

- Coloque exatamente **1 puppy** em cada linha, cada coluna e cada região colorida.
- Dois puppies **não podem se encostar**, nem na diagonal imediata (diagonais distantes são permitidas).
- Clique (ou pressione `Espaço`) para alternar a casa: **vazia → puppy → `×` → vazia**. `Delete`/`Backspace` limpa a casa em foco e as setas (`↑ ↓ ← →`), `Home` e `End` navegam pelo tabuleiro.

## O que cada parte faz

- **Prolog (`backend/prolog/queens.pl`):** declara as regras do tabuleiro com CLP(FD) (`modelo/3`), resolve por *backtracking* (`resolver/3`), conta soluções (`contar_solucoes/4`), verifica vitória e conflitos (`verificar/4`), calcula dicas obrigatórias (`dica/3`) e gera tabuleiros `easy` (5×5) e `hard` (8×8) com solução única (`gerar/3`).
- **Python (`backend/app/`):** `prolog.py` conversa com o SWI-Prolog (via `janus-swi` ou fallback via subprocesso `swipl`) e `main.py` valida os payloads com Pydantic e expõe as rotas HTTP com FastAPI. Nenhuma regra de jogo fica no Python.
- **Elm (`frontend/src/`):** segue a Arquitetura Elm (`Model`, `Msg`, `update`, `view`, `subscriptions`):
  - `Grid.elm`: tipo algébrico `Cell (Empty | Puppy | Excluded)` e operações puras sobre matrizes;
  - `Regions.elm`: nomes, raças e estado dos selos de cada região (`Empty | Filled | Crowded`);
  - `Api.elm`: chamadas HTTP, encoders/decoders JSON (`cellDecoder`) e tratamento de erros;
  - `Board.elm`, `Hud.elm`, `Sidebar.elm`, `Victory.elm`, `Icons.elm`: componentes visuais puros;
  - `Main.elm`: estado global, controle de versão das requisições, cronômetro e atalhos de teclado.

## Requisitos

- [SWI-Prolog](https://www.swi-prolog.org/Download.html) 9.2+ (`swipl` no `PATH`)
- [uv](https://docs.astral.sh/uv/) (gerencia o Python ≥ 3.11 e dependências)
- [Node.js](https://nodejs.org) 20+ com `npm`

## Como rodar

```sh
make install    # instala dependências do backend e frontend (uma vez)
make dev        # sobe backend e frontend juntos
```

Se preferir (ou caso o `make dev` apresente disputa na subida paralela), rode em dois terminais separados:

```sh
# terminal 1
make backend    # http://localhost:8000/docs

# terminal 2
make frontend   # http://localhost:5173
```

## Testes

```sh
make test                         # testes Prolog (plunit) + backend (pytest)
make test-prolog                  # só plunit (backend/prolog/test_queens.pl)
make test-backend                 # só pytest (backend/tests/test_api.py)
cd frontend && npm test           # testes unitários Elm (elm-test)
cd frontend && npx elm-format --validate src tests
```

## API

| Rota | Corpo enviado | Resposta |
| ---- | ------------- | -------- |
| `POST /api/generate` | `{"difficulty": "easy" \| "hard"}` | `{"regions": [[...]], "board": [[...]]}` |
| `POST /api/check` | `{"regions": [[...]], "board": [[...]]}` | `{"status": "incompleto" \| "conflito" \| "venceu", "conflicts": [[r, c], ...]}` |
| `POST /api/hint` | `{"regions": [[...]], "board": [[...]]}` | `{"row": r, "col": c, "value": 1}` (ou `422` se completo/impossível/ambíguo) |
| `POST /api/solve` | `{"regions": [[...]], "board": [[...]]}` | `{"regions": [[...]], "board": [[...]]}` (ou `422` se sem solução) |

## Validação da entrega

```sh
make validar
```
