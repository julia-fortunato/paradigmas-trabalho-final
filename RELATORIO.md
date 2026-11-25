# Puppies

## 1. Identificação

| Nome completo | Matrícula | Turma (14h/16h) | Usuário GitHub |
|---------------|-----------|-----------------|----------------|
| Diogo Rodrigues Barboza | 222006660 | 16h | @diogo-barboza |
| [Nome] | [000000] | [14h] | [@usuario] |
| [Nome] | [000000] | [14h] | [@usuario] |
| [Nome] | [000000] | [14h] | [@usuario] |
| [Nome] | [000000] | [14h] | [@usuario] |
| [Nome] | [000000] | [14h] | [@usuario] |

- **Nome do projeto:** Puppies
- **Nome do grupo:** MeLasqueixon
- **Repositório:** https://github.com/julia-fortunato/paradigmas-trabalho-final
- **Commit ou tag entregue:** [a definir na tag final]
- **Ponto de partida:** remix original
- **Slides da apresentação oral:** não há

## 2. Resumo

Puppies é um jogo de lógica inspirado em *Queens / Star Battle*, adaptado com temática de álbum de figurinhas de cachorrinhos: o jogador deve posicionar exatamente um puppy em cada linha, coluna e região colorida sem que dois se toquem, nem mesmo na diagonal imediata. O Prolog (CLP(FD)) resolve todas as regras do domínio — geração de tabuleiros com regiões conectadas e solução única, verificação de conflitos, dicas por prova de obrigatoriedade e resolução completa — enquanto a interface em Elm gerencia o tabuleiro, o placar, o tema claro/escuro e a navegação acessível por teclado.

## 3. Como executar

**Requisitos:**

- SWI-Prolog 9.2+ (`swipl` no `PATH`)
- Node.js 20+ com `npm`
- uv (gerencia Python 3.11+ e ambiente virtual)

**Instalação e execução:**

```sh
make install
make backend   # terminal 1: http://localhost:8000
make frontend  # terminal 2: http://localhost:5173
```

**Testes:**

```sh
make test
cd frontend && npm test
cd frontend && npx elm-format --validate src tests
```

**Testado em:** macOS (Safari e Chrome) e Linux.

## 4. Arquitetura

```text
[Elm (Vite)] --HTTP/JSON--> [FastAPI (Python)] --janus / swipl--> [SWI-Prolog]
```

| Parte | Responsabilidade | Arquivos principais |
|-------|------------------|---------------------|
| Prolog | Regras, restrições CLP(FD), gerador de regiões únicas, verificador e dica | `backend/prolog/queens.pl`, `backend/prolog/test_queens.pl` |
| Elm | Interface reativa (TEA), tipos do domínio, navegação por teclado, placar e API | `frontend/src/Main.elm`, `frontend/src/Grid.elm`, `frontend/src/Board.elm`, `frontend/src/Api.elm`, `frontend/src/Regions.elm`, `frontend/src/Hud.elm`, `frontend/src/Sidebar.elm`, `frontend/src/Victory.elm` |
| Python | Só integração: validação Pydantic, ponte `janus`/subprocesso e tradução HTTP | `backend/app/main.py`, `backend/app/prolog.py` |

## 5. Parte em Prolog

### 5.1 Predicados principais

| Predicado | Local | O que faz |
|-----------|-------|-----------|
| `modelo(+Regioes, +Tabuleiro, -Solucao)` | `backend/prolog/queens.pl:15` | Declara domínio binário `0..1`, soma `1` por linha, coluna e região e ausência de contato diagonal imediato |
| `resolver(+Regioes, +Tabuleiro, -Solucao)` | `backend/prolog/queens.pl:87` | Aplica `modelo/3` e executa `labeling([ff], Casas)` permitindo enumeração por backtracking |
| `contar_solucoes(+Regioes, +Tabuleiro, +Limite, -Qtd)` | `backend/prolog/queens.pl:92` | Conta soluções até `Limite` usando `limit/2` para provar unicidade |
| `dica(+Regioes, +Tabuleiro, -Resultado)` | `backend/prolog/queens.pl:98` | Retorna `[Linha, Coluna, 1]` apenas para posição obrigatória em todas as soluções, ou `completo`/`impossivel`/`ambiguo` |
| `verificar(+Regioes, +Tabuleiro, -Status, -Conflitos)` | `backend/prolog/queens.pl:125` | Classifica o tabuleiro em `venceu`, `conflito` ou `incompleto` e lista as coordenadas em conflito |
| `gerar(+Nivel, -Regioes, -Tabuleiro)` | `backend/prolog/queens.pl:174` | Sorteia solução, cresce regiões conectadas e refina fronteiras até garantir solução única |

### 5.2 Conceitos do paradigma lógico utilizados

- [x] Fatos e regras como base de conhecimento: `nivel/2` (`queens.pl:171-172`) e `deslocamento/2` (`queens.pl:273-276`)
- [x] Unificação e casamento de padrões: `fixar/2` (`queens.pl:47-49`), `diagonais/2` (`queens.pl:76-82`) e `casas_regiao/4` (`queens.pl:60-66`)
- [x] Recursão (inclusive sobre listas): `sem_contato/1` (`queens.pl:70-74`), `expandir_regioes/4` (`queens.pl:249-260`) e `refinar_unicidade/7` (`queens.pl:280-291`)
- [x] Backtracking e múltiplas soluções: `resolver/3` sem corte (`queens.pl:87-90`) e `busca_aleatoria/1` (`queens.pl:203-209`)
- [x] `findall/3`, `bagof/3`, `setof/3` ou similares: `contar_solucoes/4` (`queens.pl:94`), `conflitos/3` (`queens.pl:145`) e `crescer_regioes/3` (`queens.pl:234-246`)
- [x] Corte (`!`) ou negação (`\+`), e por que foram necessários: `\+ resolver(...)` em `puppy_obrigatorio/5` (`queens.pl:122`) para provar obrigatoriedade por refutação, e `!` em `em_conflito/5` (`queens.pl:154-159`) para evitar múltiplas justificativas do mesmo par
- [x] Programação por restrições (CLP(FD) ou outra): `Casas ins 0..1`, `sum(Casas, #=, 1)`, `all_distinct/1`, `transpose/2` e restrições diagonais `#=< 1` (`queens.pl:15-82`, `queens.pl:188-201`)
- [x] Predicados de ordem superior (`maplist`, `foldl`, `include`...): `maplist/3` em `modelo/3` (`queens.pl:29-33`) e `exclude/3` em `expandir_regioes/4` (`queens.pl:253`)

### 5.3 Trecho em destaque

```prolog
sem_contato([]).
sem_contato([_]).
sem_contato([Superior, Inferior | Linhas]) :-
    diagonais(Superior, Inferior),
    sem_contato([Inferior | Linhas]).

diagonais([], []).
diagonais([_], [_]).
diagonais([AcimaEsquerda, AcimaDireita | Superior],
          [AbaixoEsquerda, AbaixoDireita | Inferior]) :-
    AcimaEsquerda + AbaixoDireita #=< 1,
    AcimaDireita + AbaixoEsquerda #=< 1,
    diagonais([AcimaDireita | Superior], [AbaixoDireita | Inferior]).
```

Em vez de percorrer coordenadas com laços imperativos verificando vizinhos após cada tentativa, declaramos a restrição `AcimaEsquerda + AbaixoDireita #=< 1` entre variáveis lógicas adjacentes da matriz. O propagador do CLP(FD) poda automaticamente as diagonais assim que uma variável é fixada em `1`, mantendo a regra puramente declarativa e independente da estratégia de busca (`labeling/2`).

## 6. Parte em Elm

### 6.1 Modelo e mensagens

```elm
type Cell
    = Empty
    | Puppy
    | Excluded

type Phase
    = Generating
    | GenerationFailed Api.Error
    | Playing
    | Solved

type alias Model =
    { puzzle : Maybe Puzzle
    , original : Maybe Puzzle
    , difficulty : String
    , phase : Phase
    , outcome : Api.Outcome
    , conflicts : List ( Int, Int )
    , problem : Maybe Api.Error
    , request : Maybe Request
    , version : Int
    , dark : Bool
    , seconds : Int
    , moves : Int
    , hints : Int
    , started : Bool
    , hintAt : Maybe ( Int, Int )
    , focus : ( Int, Int )
    , winOpen : Bool
    , said : String
    , announce : String
    }

type Msg
    = NewGame String
    | GotGame Int (Result Api.Error Puzzle)
    | PressCell Int Int
    | FocusCell Int Int
    | BoardKey Board.Key
    | GotCheck Int (Result Api.Error Api.CheckResult)
    | AskHint
    | GotHint Int (Result Api.Error Api.Hint)
    | AskSolve
    | GotSolution Int (Result Api.Error Puzzle)
    | Reset
    | ToggleTheme
    | CloseVictory
    | Tick
    | NoOp
```

Em vez de representar células com inteiros soltos (`0`, `1`, `-1`) e estados da partida com múltiplos `Bool`, usamos *custom types* como `Grid.Cell`, `Phase`, `Request`, `Api.Error`, `Api.Outcome`, `Board.Mode` e `Regions.Seal`. O campo `version : Int` acompanha cada requisição assíncrona para descartar respostas antigas caso o jogador reinicie ou troque de dificuldade antes de o servidor responder.

### 6.2 Conceitos do paradigma funcional utilizados

- [x] Arquitetura Elm (Model, update, view): `frontend/src/Main.elm:44-695`
- [x] Custom types e `case` exaustivo: `Cell` (`Grid.elm:16-19`), `Phase` (`Main.elm:30-35`), `Seal` (`Regions.elm:39-42`), `Key` (`Board.elm:234-238`)
- [x] `Maybe` e `Result` no lugar de null e exceções: `Grid.at` retorna `Maybe a` (`Grid.elm:69-77`), `cellFromInt` retorna `Maybe Cell` (`Grid.elm:25-39`) e respostas HTTP usam `Result Api.Error a` (`Api.elm:69-90`)
- [x] Funções de ordem superior e aplicação parcial: `List.indexedMap`, `List.map2`, `List.filter` em `Grid.elm:80-106` e `Regions.elm:48-63`
- [x] Composição (`|>`, `>>`): `Grid.at` (`Grid.elm:74-77`) e `encodeBoard` (`Api.elm:231-233`)
- [x] Decoders e encoders JSON: `cellDecoder`, `puzzleDecoder`, `checkDecoder`, `hintDecoder`, `encodePuzzle` (`Api.elm:156-240`)
- [x] Comandos e subscriptions (efeitos controlados): `Time.every 1000` em `subscriptions` (`Main.elm:122-128`) e `Browser.Dom.focus` em `focusOn` (`Main.elm:485-487`)
- [x] Imutabilidade e atualização de records: atualização de `Model` e `Puzzle` via `{ model | ... }` em `Main.elm:170-375`

### 6.3 Trecho em destaque

```elm
cellDecoder : Decoder Cell
cellDecoder =
    Decode.int
        |> Decode.andThen
            (\value ->
                case Grid.cellFromInt value of
                    Just cell ->
                        Decode.succeed cell

                    Nothing ->
                        Decode.fail ("Valor de célula inválido: " ++ String.fromInt value)
            )
```

Ao combinar `Decode.andThen` com `Grid.cellFromInt : Int -> Maybe Cell`, garantimos na fronteira da API que nenhum inteiro fora de `-1`, `0` ou `1` entra no estado da aplicação. A refatoração de `Int` para `Cell` foi guiada diretamente pelo compilador do Elm em todos os módulos dependentes (`Api`, `Regions`, `Hud`, `Board` e `Main`).

## 7. Integração

| Rota / chamada | Entrada | Saída | Predicado Prolog |
|----------------|---------|-------|------------------|
| `POST /api/generate` | `{"difficulty": "easy" \| "hard"}` | `{"regions": [[...]], "board": [[...]]}` | `queens:gerar/3` |
| `POST /api/check` | `{"regions": [[...]], "board": [[...]]}` | `{"status": "incompleto" \| "conflito" \| "venceu", "conflicts": [[r, c], ...]}` | `queens:verificar/4` |
| `POST /api/hint` | `{"regions": [[...]], "board": [[...]]}` | `{"row": r, "col": c, "value": 1}` | `queens:dica/3` |
| `POST /api/solve` | `{"regions": [[...]], "board": [[...]]}` | `{"regions": [[...]], "board": [[...]]}` | `queens:resolver/3` |

## 8. Testes e validação

- **Prolog (`plunit`):** 20 testes (+1 sub-teste) em `backend/prolog/test_queens.pl` cobrindo restrições de linha, coluna, região, contato diagonal imediato vs diagonal distante, exclusões (`-1`), dicas (obrigatória, ambígua, completa e impossível), geração `easy`/`hard` com conectividade e unicidade de solução, e `verificar/4`.
- **Backend (`pytest`):** 13 testes em `backend/tests/test_api.py` cobrindo o fluxo completo de `generate`, `hint`, `solve` e `check` (incompleto com exclusões, vitória, conflitos de linha/diagonal/região e rejeição `422` de formatos inválidos).
- **Frontend (`elm-test`):** 34 testes em `frontend/tests/` (`GridTest.elm`, `RegionsTest.elm`, `BoardTest.elm`, `HudTest.elm`, `ApiTest.elm`) validando conversões `Cell`, limites negativos e fora da grade em `Grid.at`, imutabilidade de `setCell`, classificação de selos, navegação por teclado nas bordas e formatação de tempo/erros.

## 9. Limitações e problemas conhecidos

- No Safari (WebKit), o foco movido programaticamente por `Browser.Dom.focus` durante a navegação por setas pode não ativar `:focus-visible` caso a interação anterior tenha sido um clique de mouse, ocultando o anel visual da célula atual.
- Ao subir backend e frontend juntos com `make dev` (`make -j2`) no macOS, o Vite inicia antes do FastAPI concluir a carga do SWI-Prolog, podendo causar erro transitório na primeira requisição `/api/generate`; rodar `make backend` e `make frontend` em terminais separados evita o problema.

## 10. Contribuição de cada integrante

| Integrante | Principais contribuições |
|------------|--------------------------|
| Diogo Rodrigues Barboza | Padronização com `elm-format`, configuração e implementação dos 34 testes unitários em `elm-test`, cobertura `pytest` para `/api/check`, refatoração de células `Int` para o *custom type* `Cell` em Elm e estruturação inicial do `README.md` e `RELATORIO.md`. |
| [Nome] | [...] |
| [Nome] | [...] |
| [Nome] | [...] |
| [Nome] | [...] |
| [Nome] | [...] |

## 11. Fontes, código de terceiros e uso de IA

**Código reaproveitado.** Partimos do template oficial da disciplina (Sudoku em Prolog + Elm). Mantivemos o `Makefile`, a estrutura do servidor FastAPI (`backend/app/`) e a arquitetura base do projeto; toda a lógica em `backend/prolog/queens.pl`, os testes em `test_queens.pl`, os módulos do frontend em `frontend/src/` (exceto o `Sudoku.elm` legado) e os testes em `frontend/tests/` foram desenvolvidos pelo grupo para o jogo Puppies.

**Referências.** Documentação do SWI-Prolog (`library(clpfd)`, `library(plunit)`), documentação oficial do Elm 0.19.2 e `elm-explorations/test`, e Phosphor Icons 2.1.1 (licença MIT, em `frontend/src/Icons.elm`).

**Uso de ferramentas de IA.**

- **Faixa de uso no código:** auxiliar

| Ferramenta | Para que foi usada | Como o grupo verificou o resultado |
|------------|--------------------|------------------------------------|
| Assistente de IA (IDE) | Apoio na refatoração do tipo `Cell` em Elm, criação de testes unitários (`elm-test` e `pytest`) e revisão da documentação | Revisão manual do diff linha a linha, execução de `elm-format --validate`, `elm make`, `elm-test`, `pytest`, `plunit` e teste manual no navegador |

## 12. Apresentação oral

- **Slides:** não há
- **Roteiro:**

| Parte | Duração | Quem apresenta |
|-------|---------|----------------|
| Contexto e regras do Puppies | 2 min | [Nome] |
| Demonstração do sistema rodando | 5 min | [Nome] |
| Código Prolog (`queens.pl`) | 3 min | [Nome] |
| Código Elm (`Grid.elm`, `Api.elm`, `Main.elm`) | 3 min | [Nome] |
| Limitações e aprendizados | 2 min | [Nome] |

## 13. Reflexão sobre os paradigmas

Trabalhar com Prolog mostrou como a programação por restrições com CLP(FD) muda o foco do "como buscar" para "o que precisa ser verdade". Declarar as regras do tabuleiro (um puppy por linha, coluna, região e sem contato diagonal imediato) em `modelo/3` permitiu reutilizar exatamente a mesma especificação tanto para resolver tabuleiros quanto para provar unicidade na geração e calcular dicas obrigatórias em `dica/3`, sem duplicar algoritmos de busca.

No lado do Elm, a tipagem estática forte e a ausência de `null` e exceções tornaram as refatorações muito mais seguras. Quando substituímos os inteiros soltos (`0`, `1`, `-1`) pelo *custom type* `Cell` e alteramos `Grid.at` para retornar `Maybe a`, o próprio compilador apontou cada função e padrão de `case` que precisava ser atualizado nos demais módulos, eliminando erros silenciosos em tempo de execução.
