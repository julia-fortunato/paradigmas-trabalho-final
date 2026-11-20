:- module(queens, [modelo/3, resolver/3, contar_solucoes/4, dica/3, gerar/3]).

:- use_module(library(assoc)).
:- use_module(library(clpfd)).
:- use_module(library(random)).
:- use_module(library(solution_sequences)).

/* Representação e restrições

   Regioes contém identificadores de 1 a N. Tabuleiro usa 0 para casa livre,
   1 para puppy e -1 para exclusão. Solucao é uma matriz binária.
   O modelo declara as restrições; resolver/3 realiza a busca.
*/

modelo(Regioes, Tabuleiro, Solucao) :-
    length(Regioes, Tamanho),
    between(4, 10, Tamanho),
    matriz_quadrada(Tamanho, Regioes),
    matriz_quadrada(Tamanho, Tabuleiro),
    matriz_quadrada(Tamanho, Solucao),
    append(Regioes, Identificadores),
    maplist(integer, Identificadores),
    sort(Identificadores, Unicos),
    numlist(1, Tamanho, Unicos),
    append(Tabuleiro, Entradas),
    maplist(entrada_valida, Entradas),
    append(Solucao, Casas),
    Casas ins 0..1,
    maplist(maplist(fixar), Tabuleiro, Solucao),
    maplist(um_puppy, Solucao),
    transpose(Solucao, Colunas),
    maplist(um_puppy, Colunas),
    maplist(restringir_regiao(Identificadores, Casas), Unicos),
    sem_contato(Solucao).

matriz_quadrada(Tamanho, Matriz) :-
    length(Matriz, Tamanho),
    maplist(comprimento(Tamanho), Matriz).

comprimento(Tamanho, Lista) :-
    length(Lista, Tamanho).

entrada_valida(Valor) :-
    integer(Valor),
    memberchk(Valor, [-1, 0, 1]).

fixar(0, _).
fixar(1, Casa) :- Casa #= 1.
fixar(-1, Casa) :- Casa #= 0.

um_puppy(Casas) :-
    sum(Casas, #=, 1).

restringir_regiao(Identificadores, Casas, Regiao) :-
    casas_regiao(Identificadores, Casas, Regiao, Selecionadas),
    um_puppy(Selecionadas).

% A recursão preserva as variáveis do modelo. findall/3 as copiaria,
% desligando as restrições de região das demais restrições.
casas_regiao([], [], _, []).
casas_regiao([Identificador | Outros], [Casa | Casas], Regiao, Selecionadas) :-
    (   Identificador =:= Regiao
    ->  Selecionadas = [Casa | Resto]
    ;   Selecionadas = Resto
    ),
    casas_regiao(Outros, Casas, Regiao, Resto).

% Linha e coluna já impedem contato ortogonal. Só falta impedir as
% diagonais imediatas: diagonais distantes são permitidas neste jogo.
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

/* Resolução e dicas */

% Sem corte: o chamador pode enumerar soluções por backtracking.
resolver(Regioes, Tabuleiro, Solucao) :-
    modelo(Regioes, Tabuleiro, Solucao),
    append(Solucao, Casas),
    labeling([ff], Casas).

contar_solucoes(Regioes, Tabuleiro, Limite, Quantidade) :-
    must_be(positive_integer, Limite),
    findall(1, limit(Limite, resolver(Regioes, Tabuleiro, _)), Encontradas),
    length(Encontradas, Quantidade).

% Uma dica precisa valer em todas as soluções, não apenas na primeira.
dica(Regioes, Tabuleiro, Resultado) :-
    (   once(resolver(Regioes, Tabuleiro, Solucao))
    ->  dica_soluvel(Regioes, Tabuleiro, Solucao, Resultado)
    ;   Resultado = impossivel
    ).

dica_soluvel(Regioes, Tabuleiro, Solucao, Resultado) :-
    (   \+ puppy_pendente(Tabuleiro, Solucao, _, _)
    ->  Resultado = completo
    ;   once(puppy_obrigatorio(Regioes, Tabuleiro, Solucao, Linha, Coluna))
    ->  Resultado = [Linha, Coluna, 1]
    ;   Resultado = ambiguo
    ).

puppy_pendente(Tabuleiro, Solucao, Linha, Coluna) :-
    nth0(Linha, Solucao, LinhaSolucao),
    nth0(Coluna, LinhaSolucao, 1),
    nth0(Linha, Tabuleiro, LinhaAtual),
    nth0(Coluna, LinhaAtual, 0).

% Se excluir a casa impede qualquer solução, colocar o puppy é obrigatório.
puppy_obrigatorio(Regioes, Tabuleiro, Solucao, Linha, Coluna) :-
    puppy_pendente(Tabuleiro, Solucao, Linha, Coluna),
    substituir_casa(Tabuleiro, Linha, Coluna, -1, Alternativa),
    \+ resolver(Regioes, Alternativa, _).

/* Geração: disposição válida, crescimento de regiões e unicidade */

% Os níveis definem o tamanho do tabuleiro; ambos começam vazios (0 pistas).
nivel(easy, 5).
nivel(hard, 8).

gerar(Nivel, Regioes, Tabuleiro) :-
    must_be(oneof([easy, hard]), Nivel),
    nivel(Nivel, Tamanho),
    matriz_zeros(Tamanho, Tabuleiro),
    sortear_solucao(Tamanho, Colunas, Solucao),
    gerar_regioes_unicas(Tamanho, Colunas, Tabuleiro, Solucao, RegioesBrutas),
    embaralhar_regioes(Tamanho, RegioesBrutas, Regioes).

matriz_zeros(Tamanho, Matriz) :-
    length(Linha, Tamanho),
    maplist(=(0), Linha),
    length(Matriz, Tamanho),
    maplist(=(Linha), Matriz).

sortear_solucao(Tamanho, Colunas, Solucao) :-
    length(Colunas, Tamanho),
    Colunas ins 1..Tamanho,
    all_distinct(Colunas),
    separadas(Colunas),
    once(busca_aleatoria(Colunas)),
    numlist(1, Tamanho, Indices),
    maplist(linha_solucao(Indices), Colunas, Solucao).

separadas([]).
separadas([_]).
separadas([Coluna, Proxima | Resto]) :-
    abs(Coluna - Proxima) #> 1,
    separadas([Proxima | Resto]).

busca_aleatoria([]).
busca_aleatoria([Coluna | Resto]) :-
    fd_set(Coluna, Dominio),
    fdset_to_list(Dominio, Valores),
    random_permutation(Valores, Ordem),
    member(Coluna, Ordem),
    busca_aleatoria(Resto).

linha_solucao(Indices, ColunaPuppy, Linha) :-
    maplist(valor_casa(ColunaPuppy), Indices, Linha).

valor_casa(ColunaPuppy, Coluna, Valor) :-
    (   Coluna =:= ColunaPuppy
    ->  Valor = 1
    ;   Valor = 0
    ).

% Cresce regiões conectadas a partir dos puppies e ajusta a fronteira
% eliminando soluções alternativas até o tabuleiro vazio ter solução única.
gerar_regioes_unicas(Tamanho, Colunas, Vazio, Solucao, Regioes) :-
    repeat,
    crescer_regioes(Tamanho, Colunas, MapaInicial),
    (   refinar_unicidade(Tamanho, MapaInicial, Vazio, Solucao, [], 25, MapaFinal)
    ->  !
    ;   fail
    ),
    mapa_para_matriz(Tamanho, MapaFinal, Regioes).

% Expansão aleatória por arestas de fronteira: preserva conectividade
% ortogonal de todas as regiões e gera tamanhos variados naturalmente.
crescer_regioes(Tamanho, Colunas, MapaFinal) :-
    findall((Linha-Coluna)-Regiao,
            ( nth1(Regiao, Colunas, ColunaUm),
              Linha is Regiao - 1,
              Coluna is ColunaUm - 1
            ),
            Sementes),
    list_to_assoc(Sementes, MapaInicial),
    findall(Vizinho-Regiao,
            ( member(Posicao-Regiao, Sementes),
              vizinho_ortogonal(Tamanho, Posicao, Vizinho),
              \+ get_assoc(Vizinho, MapaInicial, _)
            ),
            Arestas),
    expandir_regioes(Tamanho, Arestas, MapaInicial, MapaFinal).

expandir_regioes(_, [], Mapa, Mapa) :- !.
expandir_regioes(Tamanho, Arestas, Mapa, MapaFinal) :-
    random_member(Posicao-Regiao, Arestas),
    put_assoc(Posicao, Mapa, Regiao, MapaAtualizado),
    exclude(mesma_posicao(Posicao), Arestas, ArestasRestantes),
    findall(NovoVizinho-Regiao,
            ( vizinho_ortogonal(Tamanho, Posicao, NovoVizinho),
              \+ get_assoc(NovoVizinho, MapaAtualizado, _)
            ),
            NovasArestas),
    append(NovasArestas, ArestasRestantes, ProximasArestas),
    expandir_regioes(Tamanho, ProximasArestas, MapaAtualizado, MapaFinal).

mesma_posicao(Posicao, Posicao-_).

vizinho_ortogonal(Tamanho, Linha-Coluna, VizLinha-VizColuna) :-
    deslocamento(DL, DC),
    VizLinha is Linha + DL,
    VizColuna is Coluna + DC,
    VizLinha >= 0,
    VizLinha < Tamanho,
    VizColuna >= 0,
    VizColuna < Tamanho.

deslocamento(-1, 0).
deslocamento(1, 0).
deslocamento(0, -1).
deslocamento(0, 1).

% Se existir outra solução além da sorteada, move uma casa dessa alternativa
% para uma região vizinha mantendo a conectividade e preservando a solução alvo.
refinar_unicidade(Tamanho, Mapa, Vazio, Solucao, Proibidas, Tentativas, MapaFinal) :-
    mapa_para_matriz(Tamanho, Mapa, Regioes),
    (   outra_solucao(Regioes, Vazio, Solucao, Alternativa)
    ->  Tentativas > 0,
        escolher_troca(Tamanho, Mapa, Solucao, Alternativa, Proibidas,
                       Posicao, RegiaoAtual, NovaRegiao),
        put_assoc(Posicao, Mapa, NovaRegiao, MapaAtualizado),
        Restantes is Tentativas - 1,
        refinar_unicidade(Tamanho, MapaAtualizado, Vazio, Solucao,
                          [Posicao-RegiaoAtual | Proibidas], Restantes, MapaFinal)
    ;   MapaFinal = Mapa
    ).

outra_solucao(Regioes, Vazio, Solucao, Alternativa) :-
    resolver(Regioes, Vazio, Alternativa),
    Alternativa \== Solucao,
    !.

escolher_troca(Tamanho, Mapa, Solucao, Alternativa, Proibidas,
               Posicao, RegiaoAtual, NovaRegiao) :-
    assoc_to_list(Mapa, Pares),
    findall(Linha-Coluna,
            ( nth0(Linha, Alternativa, LinhaAlt),
              nth0(Coluna, LinhaAlt, 1),
              nth0(Linha, Solucao, LinhaSol),
              nth0(Coluna, LinhaSol, 0)
            ),
            Diferencas),
    findall(Prioridade-(PosCand-RegAtual-RegViz),
            troca_candidata(Tamanho, Mapa, Pares, Diferencas, Proibidas,
                            Prioridade, PosCand, RegAtual, RegViz),
            Opcoes),
    Opcoes \= [],
    keysort(Opcoes, [_- (Posicao-RegiaoAtual-NovaRegiao) | _]).

troca_candidata(Tamanho, Mapa, Pares, Diferencas, Proibidas,
                Prioridade, Posicao, RegiaoAtual, RegiaoVizinha) :-
    member(Posicao, Diferencas),
    get_assoc(Posicao, Mapa, RegiaoAtual),
    findall(RV,
            ( vizinho_ortogonal(Tamanho, Posicao, Vizinho),
              get_assoc(Vizinho, Mapa, RV),
              RV =\= RegiaoAtual,
              \+ memberchk(Posicao-RV, Proibidas)
            ),
            VizinhasBrutas),
    sort(VizinhasBrutas, Vizinhas),
    Vizinhas \= [],
    findall(Casa, member(Casa-RegiaoAtual, Pares), CasasRegiao),
    select(Posicao, CasasRegiao, Restantes),
    regiao_conectada(Tamanho, Restantes),
    length(Restantes, TamRestante),
    member(RegiaoVizinha, Vizinhas),
    findall(CasaViz, member(CasaViz-RegiaoVizinha, Pares), CasasVizinha),
    length(CasasVizinha, TamVizinha),
    % Evita reduzir regiões a uma única casa quando há outra opção e
    % transfere casas de regiões menores para vizinhas maiores.
    (   TamRestante >= 2
    ->  Penalidade = 0
    ;   Penalidade = 200
    ),
    random(Aleatorio),
    Prioridade is Penalidade + TamRestante - TamVizinha + Aleatorio.

regiao_conectada(Tamanho, [Inicio | Resto]) :-
    visitar_regiao(Tamanho, [Inicio], [Inicio], [Inicio | Resto], Visitadas),
    length([Inicio | Resto], Total),
    length(Visitadas, Total).

visitar_regiao(_, [], Visitadas, _, Visitadas) :- !.
visitar_regiao(Tamanho, [Atual | Fila], Visitadas, Permitidas, Final) :-
    findall(Vizinho,
            ( vizinho_ortogonal(Tamanho, Atual, Vizinho),
              memberchk(Vizinho, Permitidas),
              \+ memberchk(Vizinho, Visitadas)
            ),
            NovosBrutos),
    sort(NovosBrutos, Novos),
    append(Fila, Novos, NovaFila),
    append(Novos, Visitadas, NovasVisitadas),
    visitar_regiao(Tamanho, NovaFila, NovasVisitadas, Permitidas, Final).

mapa_para_matriz(Tamanho, Mapa, Matriz) :-
    Ultimo is Tamanho - 1,
    numlist(0, Ultimo, Indices),
    maplist(linha_mapa(Mapa, Indices), Indices, Matriz).

linha_mapa(Mapa, Colunas, Linha, Valores) :-
    maplist(casa_mapa(Mapa, Linha), Colunas, Valores).

casa_mapa(Mapa, Linha, Coluna, Regiao) :-
    get_assoc(Linha-Coluna, Mapa, Regiao).

% Embaralha os identificadores de 1 a N para não associar o número da região
% à linha do puppy na solução sorteada.
embaralhar_regioes(Tamanho, Regioes, Embaralhadas) :-
    numlist(1, Tamanho, Originais),
    random_permutation(Originais, Permutacao),
    maplist(maplist(trocar_regiao(Permutacao)), Regioes, Embaralhadas).

trocar_regiao(Permutacao, Original, Novo) :-
    nth1(Original, Permutacao, Novo).

% Constrói uma nova matriz sem alterar a anterior.
substituir_casa(Tabuleiro, Linha, Coluna, Valor, Novo) :-
    nth0(Linha, Tabuleiro, Valores, OutrasLinhas),
    nth0(Coluna, Valores, _, Restantes),
    nth0(Coluna, NovaLinha, Valor, Restantes),
    nth0(Linha, Novo, NovaLinha, OutrasLinhas).
