module RegionsTest exposing (suite)

import Expect
import Regions exposing (Seal(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Regions"
        [ describe "name"
            [ test "retorna o nome da primeira e da décima região" <|
                \_ ->
                    ( Regions.name 1, Regions.name 10 )
                        |> Expect.equal ( "Azul", "Gelo" )
            , test "retorna string vazia para região fora do intervalo" <|
                \_ ->
                    Regions.name 99
                        |> Expect.equal ""
            ]
        , describe "breed"
            [ test "repete as raças ciclicamente a partir da sexta região" <|
                \_ ->
                    Regions.breed 6
                        |> Expect.equal (Regions.breed 1)
            ]
        , describe "seals"
            [ test "classifica regiões como Empty, Filled e Crowded ignorando exclusões" <|
                \_ ->
                    let
                        regions =
                            [ [ 1, 1, 2 ]
                            , [ 1, 3, 2 ]
                            , [ 3, 3, 2 ]
                            ]

                        board =
                            [ [ 1, -1, 0 ]
                            , [ 0, 1, -1 ]
                            , [ 1, 0, 0 ]
                            ]
                    in
                    Regions.seals 3 regions board
                        |> Expect.equal
                            [ ( 1, Filled )
                            , ( 2, Empty )
                            , ( 3, Crowded )
                            ]
            ]
        ]
