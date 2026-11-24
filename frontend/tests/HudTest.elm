module HudTest exposing (suite)

import Expect
import Hud
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Hud.clock"
        [ test "formata zero segundos como 00:00" <|
            \_ ->
                Hud.clock 0
                    |> Expect.equal "00:00"
        , test "preenche com zero à esquerda abaixo de 10 segundos" <|
            \_ ->
                Hud.clock 7
                    |> Expect.equal "00:07"
        , test "formata minutos e segundos corretamente" <|
            \_ ->
                Hud.clock 125
                    |> Expect.equal "02:05"
        , test "suporta tempos acima de uma hora sem truncar minutos" <|
            \_ ->
                Hud.clock 3661
                    |> Expect.equal "61:01"
        ]
