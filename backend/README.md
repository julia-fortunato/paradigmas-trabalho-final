# Backend Puppies

Regras: exatamente um puppy por linha, coluna e região; puppies não podem
se tocar, nem diagonalmente. Diagonais distantes são permitidas.

## Executar e testar

Requisitos: SWI-Prolog com suporte a Janus, Python >= 3.11 e uv.
No Windows, a compila??o do `janus-swi` tamb?m requer Visual Studio Build
Tools 2022 com a carga de trabalho C++ e o SDK do Windows. Instala??o:

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --silent --accept-package-agreements --accept-source-agreements --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

Ambiente validado: Windows x64, Python 3.13.15, SWI-Prolog 10.0.2 e
janus-swi 1.5.3. Ap?s instalar as ferramentas, `uv sync` compila o Janus e
instala as depend?ncias no ambiente virtual local `backend/.venv`.

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
