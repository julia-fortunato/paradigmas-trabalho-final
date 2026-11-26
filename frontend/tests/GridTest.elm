module GridTest exposing (suite)

import Expect
import Grid exposing (Cell(..))
import Test exposing (Test, describe, test)


sampleGrid : List (List Cell)
sampleGrid =
    [ [ Puppy, Empty, Excluded ]
    , [ Empty, Puppy, Empty ]
    , [ Excluded, Empty, Empty ]
    ]


suite : Test
suite =
    describe "Grid"
        [ describe "Cell conversions"
            [ test "converte inteiros válidos para Cell" <|
                \_ ->
                    [ Grid.cellFromInt 0, Grid.cellFromInt 1, Grid.cellFromInt -1 ]
                        |> Expect.equal [ Just Empty, Just Puppy, Just Excluded ]
            , test "rejeita inteiros fora de {-1, 0, 1}" <|
                \_ ->
                    [ Grid.cellFromInt 2, Grid.cellFromInt -2, Grid.cellFromInt 99 ]
                        |> Expect.equal [ Nothing, Nothing, Nothing ]
            , test "converte Cell de volta para o inteiro da API" <|
                \_ ->
                    [ Grid.cellToInt Empty, Grid.cellToInt Puppy, Grid.cellToInt Excluded ]
                        |> Expect.equal [ 0, 1, -1 ]
            , test "nextCell percorre o ciclo Empty -> Puppy -> Excluded -> Empty" <|
                \_ ->
                    [ Grid.nextCell Empty, Grid.nextCell Puppy, Grid.nextCell Excluded ]
                        |> Expect.equal [ Puppy, Excluded, Empty ]
            ]
        , describe "at"
            [ test "lê o valor de uma posição válida" <|
                \_ ->
                    Grid.at 1 1 sampleGrid
                        |> Expect.equal (Just Puppy)
            , test "lê exclusão (Excluded) corretamente" <|
                \_ ->
                    Grid.at 0 2 sampleGrid
                        |> Expect.equal (Just Excluded)
            , test "retorna Nothing para índices negativos" <|
                \_ ->
                    ( Grid.at -1 0 sampleGrid, Grid.at 0 -1 sampleGrid )
                        |> Expect.equal ( Nothing, Nothing )
            , test "retorna Nothing quando a linha está fora dos limites" <|
                \_ ->
                    Grid.at 5 0 sampleGrid
                        |> Expect.equal Nothing
            , test "retorna Nothing quando a coluna está fora dos limites" <|
                \_ ->
                    Grid.at 0 9 sampleGrid
                        |> Expect.equal Nothing
            , test "retorna Nothing em grade vazia" <|
                \_ ->
                    Grid.at 0 0 []
                        |> Expect.equal Nothing
            ]
        , describe "setCell"
            [ test "atualiza apenas a casa alvo preservando as demais" <|
                \_ ->
                    Grid.setCell 1 2 Puppy sampleGrid
                        |> Expect.equal
                            [ [ Puppy, Empty, Excluded ]
                            , [ Empty, Puppy, Puppy ]
                            , [ Excluded, Empty, Empty ]
                            ]
            , test "não altera a grade quando o índice está fora dos limites" <|
                \_ ->
                    Grid.setCell 10 10 Puppy sampleGrid
                        |> Expect.equal sampleGrid
            ]
        , describe "count"
            [ test "conta puppies (Puppy) na grade" <|
                \_ ->
                    Grid.count Puppy sampleGrid
                        |> Expect.equal 2
            , test "conta exclusões (Excluded) na grade" <|
                \_ ->
                    Grid.count Excluded sampleGrid
                        |> Expect.equal 2
            , test "conta casas vazias (Empty) na grade" <|
                \_ ->
                    Grid.count Empty sampleGrid
                        |> Expect.equal 5
            , test "retorna 0 em grade vazia" <|
                \_ ->
                    Grid.count Puppy []
                        |> Expect.equal 0
            ]
        ]
