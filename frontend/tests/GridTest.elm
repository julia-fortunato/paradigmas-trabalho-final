module GridTest exposing (suite)

import Expect
import Grid
import Test exposing (Test, describe, test)


sampleGrid : List (List Int)
sampleGrid =
    [ [ 1, 0, -1 ]
    , [ 0, 1, 0 ]
    , [ -1, 0, 0 ]
    ]


suite : Test
suite =
    describe "Grid"
        [ describe "at"
            [ test "lê o valor de uma posição válida" <|
                \_ ->
                    Grid.at 1 1 sampleGrid
                        |> Expect.equal 1
            , test "lê exclusão (-1) corretamente" <|
                \_ ->
                    Grid.at 0 2 sampleGrid
                        |> Expect.equal -1
            , test "retorna 0 quando a linha está fora dos limites" <|
                \_ ->
                    Grid.at 5 0 sampleGrid
                        |> Expect.equal 0
            , test "retorna 0 quando a coluna está fora dos limites" <|
                \_ ->
                    Grid.at 0 9 sampleGrid
                        |> Expect.equal 0
            , test "retorna 0 em grade vazia" <|
                \_ ->
                    Grid.at 0 0 []
                        |> Expect.equal 0
            ]
        , describe "setCell"
            [ test "atualiza apenas a casa alvo preservando as demais" <|
                \_ ->
                    Grid.setCell 1 2 1 sampleGrid
                        |> Expect.equal
                            [ [ 1, 0, -1 ]
                            , [ 0, 1, 1 ]
                            , [ -1, 0, 0 ]
                            ]
            , test "não altera a grade quando o índice está fora dos limites" <|
                \_ ->
                    Grid.setCell 10 10 1 sampleGrid
                        |> Expect.equal sampleGrid
            ]
        , describe "count"
            [ test "conta puppies (1) na grade" <|
                \_ ->
                    Grid.count 1 sampleGrid
                        |> Expect.equal 2
            , test "conta exclusões (-1) na grade" <|
                \_ ->
                    Grid.count -1 sampleGrid
                        |> Expect.equal 2
            , test "conta casas vazias (0) na grade" <|
                \_ ->
                    Grid.count 0 sampleGrid
                        |> Expect.equal 5
            , test "retorna 0 em grade vazia" <|
                \_ ->
                    Grid.count 1 []
                        |> Expect.equal 0
            ]
        ]
