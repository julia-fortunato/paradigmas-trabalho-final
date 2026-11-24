module BoardTest exposing (suite)

import Board exposing (Key(..))
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Board"
        [ describe "cellId"
            [ test "gera o id esperado para linha e coluna" <|
                \_ ->
                    Board.cellId 2 4
                        |> Expect.equal "cell-2-4"
            ]
        , describe "navigate"
            [ test "move uma casa para baixo e para a direita dentro dos limites" <|
                \_ ->
                    Board.navigate 5 ( 1, 2 ) (Step 1 0)
                        |> Expect.equal ( 2, 2 )
            , test "não ultrapassa a borda superior esquerda" <|
                \_ ->
                    Board.navigate 5 ( 0, 0 ) (Step -1 0)
                        |> Expect.equal ( 0, 0 )
            , test "não ultrapassa a borda inferior direita" <|
                \_ ->
                    Board.navigate 5 ( 4, 4 ) (Step 0 1)
                        |> Expect.equal ( 4, 4 )
            , test "Home vai para o início da linha e Ctrl+Home para (0, 0)" <|
                \_ ->
                    ( Board.navigate 5 ( 3, 4 ) (Home False)
                    , Board.navigate 5 ( 3, 4 ) (Home True)
                    )
                        |> Expect.equal ( ( 3, 0 ), ( 0, 0 ) )
            , test "End vai para o fim da linha e Ctrl+End para o fim do tabuleiro" <|
                \_ ->
                    ( Board.navigate 5 ( 2, 1 ) (End False)
                    , Board.navigate 5 ( 2, 1 ) (End True)
                    )
                        |> Expect.equal ( ( 2, 4 ), ( 4, 4 ) )
            , test "Clear mantém o foco na mesma casa" <|
                \_ ->
                    Board.navigate 8 ( 3, 5 ) Clear
                        |> Expect.equal ( 3, 5 )
            ]
        ]
