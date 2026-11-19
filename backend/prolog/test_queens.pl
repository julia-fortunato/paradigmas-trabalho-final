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

test(geracao, [forall(member(Nivel, [easy, hard]))]) :-
    gerar(Nivel, Regioes, Tabuleiro),
    contar_solucoes(Regioes, Tabuleiro, 2, 1),
    dica(Regioes, Tabuleiro, [Linha, Coluna, 1]),
    nth0(Linha, Tabuleiro, Valores),
    nth0(Coluna, Valores, 0).

:- end_tests(queens).
