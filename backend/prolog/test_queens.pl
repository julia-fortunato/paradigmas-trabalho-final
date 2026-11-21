:- use_module(queens).
:- use_module(library(plunit)).

:- begin_tests(queens).

% Regiões por linha deixam duas soluções, úteis para testar ambiguidade.
exemplo([[1, 1, 1, 1],
         [2, 2, 2, 2],
         [3, 3, 3, 3],
         [4, 4, 4, 4]],
        [[0, 0, 0, 0],
         [0, 0, 0, 0],
         [0, 0, 0, 0],
         [0, 0, 0, 0]]).

solucao_exemplo([[0, 1, 0, 0],
                 [0, 0, 0, 1],
                 [1, 0, 0, 0],
                 [0, 0, 1, 0]]).

/* Restrições e enumeração */

test(multiplas) :-
    exemplo(Regioes, Tabuleiro),
    contar_solucoes(Regioes, Tabuleiro, 2, 2).

test(linha_repetida, fail) :-
    exemplo(Regioes, [_ | Linhas]),
    resolver(Regioes, [[1, 1, 0, 0] | Linhas], _).

test(coluna_repetida, fail) :-
    exemplo(Regioes, _),
    Tabuleiro = [[1, 0, 0, 0],
                 [0, 0, 0, 0],
                 [1, 0, 0, 0],
                 [0, 0, 0, 0]],
    resolver(Regioes, Tabuleiro, _).

test(contato_diagonal, fail) :-
    exemplo(Regioes, _),
    Tabuleiro = [[1, 0, 0, 0],
                 [0, 1, 0, 0],
                 [0, 0, 0, 0],
                 [0, 0, 0, 0]],
    resolver(Regioes, Tabuleiro, _).

test(regiao_repetida, fail) :-
    % A disposição respeita linhas, colunas e contato, mas repete a região 1.
    Regioes = [[1, 1, 1, 1],
               [2, 2, 1, 1],
               [3, 3, 4, 4],
               [3, 3, 4, 4]],
    solucao_exemplo(Tabuleiro),
    resolver(Regioes, Tabuleiro, _).

test(diagonal_distante, nondet) :-
    exemplo(Regioes, _),
    solucao_exemplo(Tabuleiro),
    resolver(Regioes, Tabuleiro, _).

test(exclusao, nondet) :-
    exemplo(Regioes, _),
    Tabuleiro = [[0, -1, 0, 0],
                 [0, 0, 0, 0],
                 [0, 0, 0, 0],
                 [0, 0, 0, 0]],
    resolver(Regioes, Tabuleiro, [PrimeiraLinha | _]),
    nth0(1, PrimeiraLinha, 0).

test(formato, fail) :-
    resolver([[1]], [[0]], _).

/* Dicas: ambiguidade, conclusão e impossibilidade */

test(dica_ambigua) :-
    exemplo(Regioes, Tabuleiro),
    dica(Regioes, Tabuleiro, ambiguo).

test(completo) :-
    exemplo(Regioes, Tabuleiro),
    once(resolver(Regioes, Tabuleiro, Solucao)),
    dica(Regioes, Solucao, completo).

test(impossivel) :-
    exemplo(Regioes, [_ | Linhas]),
    dica(Regioes, [[1, 1, 0, 0] | Linhas], impossivel).

/* Geração nos dois níveis */

test(nivel_invalido, error(type_error(_, medium))) :-
    gerar(medium, _, _).

test(geracao, [forall(member(Nivel-Tamanho, [easy-5, hard-8]))]) :-
    gerar(Nivel, Regioes, Tabuleiro),
    length(Regioes, Tamanho),
    length(Tabuleiro, Tamanho),
    append(Tabuleiro, Casas),
    maplist(=(0), Casas),
    contar_solucoes(Regioes, Tabuleiro, 2, 1),
    regioes_conectadas(Regioes),
    dica(Regioes, Tabuleiro, [Linha, Coluna, 1]),
    nth0(Linha, Tabuleiro, Valores),
    nth0(Coluna, Valores, 0).

test(ids_regioes_embaralhados) :-
    % Em várias gerações, os IDs das regiões não devem ficar presos à linha do puppy.
    once((
        between(1, 5, _),
        gerar(easy, Regioes, Tabuleiro),
        once(resolver(Regioes, Tabuleiro, Solucao)),
        nth1(Linha, Solucao, LinhaSolucao),
        nth1(Coluna, LinhaSolucao, 1),
        nth1(Linha, Regioes, LinhaRegioes),
        nth1(Coluna, LinhaRegioes, Regiao),
        Regiao =\= Linha
    )).

regioes_conectadas(Regioes) :-
    length(Regioes, Tamanho),
    forall(between(1, Tamanho, Regiao),
           ( findall(L-C,
                     ( nth0(L, Regioes, Linha),
                       nth0(C, Linha, Regiao)
                     ),
                     Casas),
             Casas = [Inicio | _],
             alcancaveis([Inicio], [Inicio], Casas, Visitadas),
             length(Casas, Total),
             length(Visitadas, Total)
           )).

alcancaveis([], Visitadas, _, Visitadas) :- !.
alcancaveis([L-C | Fila], Visitadas, Permitidas, Final) :-
    findall(VL-VC,
            ( member(DL-DC, [(-1)-0, 1-0, 0-(-1), 0-1]),
              VL is L + DL,
              VC is C + DC,
              memberchk(VL-VC, Permitidas),
              \+ memberchk(VL-VC, Visitadas)
            ),
            Novos0),
    sort(Novos0, Novos),
    append(Fila, Novos, NovaFila),
    append(Novos, Visitadas, NovasVisitadas),
    alcancaveis(NovaFila, NovasVisitadas, Permitidas, Final).



    test(verificar_venceu) :-
    exemplo(Regioes, _),
    solucao_exemplo(Tabuleiro),
    verificar(Regioes, Tabuleiro, venceu, []).

test(verificar_incompleto) :-
    exemplo(Regioes, Tabuleiro),
    verificar(Regioes, Tabuleiro, incompleto, []).

test(verificar_ignora_exclusoes) :-
    exemplo(Regioes, [[_ | Resto] | Linhas]),
    verificar(Regioes, [[-1 | Resto] | Linhas], incompleto, []).

test(verificar_conflito_linha) :-
    exemplo(Regioes, [_ | Linhas]),
    verificar(Regioes, [[1, 0, 1, 0] | Linhas], conflito, [[0, 0], [0, 2]]).

test(verificar_conflito_diagonal) :-
    exemplo(Regioes, [_, _ | Linhas]),
    verificar(Regioes, [[1, 0, 0, 0], [0, 1, 0, 0] | Linhas],
              conflito, [[0, 0], [1, 1]]).

test(verificar_conflito_regiao) :-
    % (0,0) e (1,2) estão na região 1, sem compartilhar linha, coluna nem diagonal.
    Regioes = [[1, 1, 1, 1],
               [2, 2, 1, 1],
               [3, 3, 4, 4],
               [3, 3, 4, 4]],
    Tabuleiro = [[1, 0, 0, 0],
                 [0, 0, 1, 0],
                 [0, 0, 0, 0],
                 [0, 0, 0, 0]],
    verificar(Regioes, Tabuleiro, conflito, [[0, 0], [1, 2]]).
:- end_tests(queens).
