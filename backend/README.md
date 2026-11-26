# Backend Puppies

Regras: exatamente um puppy por linha, coluna e região; puppies não podem
se tocar, nem diagonalmente. Diagonais distantes são permitidas.

## Executar e testar

Requisitos: SWI-Prolog, Python >= 3.11 e uv. O comando `swipl` deve estar no
PATH; no Windows, a ponte também procura `C:\Program Files\swipl\bin\swipl.exe`.
Sem Janus, cada chamada da API executa o SWI-Prolog como subprocesso. As regras
continuam em `prolog/queens.pl`.

Janus é opcional. Para usá-lo, instale a dependência extra com `uv sync --extra janus`.
No Windows, a compilação do `janus-swi` requer Visual Studio Build Tools com C++.

Na pasta backend:

```
uv sync
uv run fastapi dev app/main.py
uv run pytest
swipl -g run_tests -t halt prolog/test_queens.pl
```

O arquivo test_sudoku.pl apenas encaminha os testes para manter o Makefile
original funcionando sem alterações fora do backend.

## Contrato HTTP

- POST /api/generate: `{"difficulty":"easy"}` ou `{"difficulty":"hard"}`.
  Retorna `{"regions": [...], "board": [...]}`.
- POST /api/solve: recebe esse mesmo objeto e retorna as regiões e a solução.
- POST /api/hint: recebe esse objeto e retorna `{"row":0,"col":1,"value":1}`.
  Coordenadas começam em zero. Erros de formato, impossibilidade, conclusão
  ou ausência de dica obrigatória retornam 422 com `detail`.

`regions` é uma matriz N×N com identificadores de 1 a N, todos presentes.
`board` usa 0 para casa livre, 1 para puppy e -1 para exclusão do jogador.
A solução usa 0 e 1. Um jogo está completo quando os N puppies estão corretos,
mesmo que sobrem zeros. Puppies iniciais devem ser preservados pelo cliente.
A API não mantém sessão; avalia o estado completo enviado pelo cliente.

Fácil: 5×5, sem pistas iniciais. Difícil: 8×8, sem pistas iniciais.
Os níveis são parâmetros estruturais, não uma medição de dificuldade humana.
O gerador cresce regiões conectadas irregularmente a partir da solução,
refina a fronteira até garantir solução única no tabuleiro vazio e embaralha
os identificadores de 1 a N; mapas personalizados são aceitos mesmo com
regiões desconectadas.

## Paradigma lógico e avaliação

`modelo/3` declara domínios binários e somas por linha, coluna e região,
mais incompatibilidade nas diagonais imediatas. `resolver/3` separa a busca
(labeling) dessas restrições e permite enumeração por backtracking.
`contar_solucoes/4` limita essa enumeração para verificar unicidade.
`dica/3` prova que excluir uma posição torna o problema impossível antes de
sugeri-la. `gerar/3` usa o mesmo resolvedor para preservar solução única.
Python só valida formato, chama Janus e traduz resultados HTTP.

O frontend original de Sudoku precisa ser adaptado ao contrato acima e à
renderização do cachorrinho; ele não foi alterado nesta etapa.
