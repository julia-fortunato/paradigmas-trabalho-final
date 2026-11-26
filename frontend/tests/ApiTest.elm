module ApiTest exposing (suite)

import Api
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Api.errorText"
        [ test "retorna mensagem amigável para Offline" <|
            \_ ->
                Api.errorText Api.Offline
                    |> Expect.equal "Sem conexão com a API na porta 8000."
        , test "preserva o detalhe vindo do backend em Rejected" <|
            \_ ->
                Api.errorText (Api.Rejected "Este tabuleiro não tem solução.")
                    |> Expect.equal "Este tabuleiro não tem solução."
        , test "retorna mensagem genérica para Failed" <|
            \_ ->
                Api.errorText Api.Failed
                    |> Expect.equal "Não foi possível completar a operação. Tente de novo."
        ]
