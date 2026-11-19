:- module(queens, [modelo/3, resolver/3, contar_solucoes/4, dica/3, gerar/3]).

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

/* Geração: disposição válida, regiões e remoção de pistas */

% O minimo de pistas é um alvo estrutural, não uma medida humana de esforço.
nivel(easy, 5, 2).
nivel(hard, 8, 0).

gerar(Nivel, Regioes, Tabuleiro) :-
    must_be(oneof([easy, hard]), Nivel),
    nivel(Nivel, Tamanho, Minimo),
    length(Colunas, Tamanho),
    Colunas ins 1..Tamanho,
    all_distinct(Colunas),
    separadas(Colunas),
    once(busca_aleatoria(Colunas)),
    numlist(1, Tamanho, Indices),
    maplist(linha_regioes(Colunas, Indices), Indices, Regioes),
    maplist(linha_solucao(Indices), Colunas, Completo),
    findall(Linha-Coluna,
            ( nth0(Linha, Completo, Valores), nth0(Coluna, Valores, 1) ),
            Posicoes),
    random_permutation(Posicoes, Ordem),
    remover_pistas(Ordem, Minimo, Regioes, Completo, Tabuleiro).

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

linha_regioes(Colunas, Indices, Linha, Regioes) :-
    maplist(regiao_proxima(Colunas, Linha), Indices, Regioes).

% Distância Manhattan ao puppy mais próximo, com desempate pelo índice.
% Essa construção produz regiões conectadas e preserva a solução inicial.
regiao_proxima(Colunas, Linha, Coluna, Identificador) :-
    findall(Distancia-Indice,
            ( nth1(Indice, Colunas, ColunaPuppy),
              Distancia is abs(Linha - Indice) + abs(Coluna - ColunaPuppy)
            ),
            Distancias),
    keysort(Distancias, [_-Identificador | _]).

linha_solucao(Indices, ColunaPuppy, Linha) :-
    maplist(valor_casa(ColunaPuppy), Indices, Linha).

valor_casa(ColunaPuppy, Coluna, Valor) :-
    (   Coluna =:= ColunaPuppy
    ->  Valor = 1
    ;   Valor = 0
    ).

% Mantém pistas extras quando removê-las destruiria a unicidade.
remover_pistas([], _, _, Tabuleiro, Tabuleiro).
remover_pistas([Linha-Coluna | Resto], Minimo, Regioes, Atual, Final) :-
    append(Atual, Casas),
    sum_list(Casas, Quantidade),
    (   Quantidade > Minimo,
        substituir_casa(Atual, Linha, Coluna, 0, Candidato),
        contar_solucoes(Regioes, Candidato, 2, 1)
    ->  Proximo = Candidato
    ;   Proximo = Atual
    ),
    remover_pistas(Resto, Minimo, Regioes, Proximo, Final).

% Constrói uma nova matriz sem alterar a anterior.
substituir_casa(Tabuleiro, Linha, Coluna, Valor, Novo) :-
    nth0(Linha, Tabuleiro, Valores, OutrasLinhas),
    nth0(Coluna, Valores, _, Restantes),
    nth0(Coluna, NovaLinha, Valor, Restantes),
    nth0(Linha, Novo, NovaLinha, OutrasLinhas).
