module Api exposing
    ( CheckResult
    , Error(..)
    , Hint
    , Outcome(..)
    , Puzzle
    , check
    , errorText
    , generate
    , hint
    , solve
    )

{-| Comunicação com o backend FastAPI + Prolog.

Todas as regras do jogo ficam no Prolog; aqui só montamos os pedidos JSON e
lemos as respostas.

-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode



-- TIPOS


type alias Grid =
    List (List Int)


type alias Puzzle =
    { regions : Grid, board : Grid }


type Outcome
    = Incomplete
    | Conflict
    | Won


type alias CheckResult =
    { outcome : Outcome, conflicts : List ( Int, Int ) }


type alias Hint =
    { row : Int, col : Int, value : Int }


{-| Erros que a interface sabe explicar.

  - `Offline`: a API não respondeu (servidor desligado, porta errada).
  - `Rejected`: a API recusou o pedido e explicou o motivo em `detail`.
  - `Failed`: qualquer outra falha.

-}
type Error
    = Offline
    | Rejected String
    | Failed



-- PEDIDOS


generate : String -> (Result Error Puzzle -> msg) -> Cmd msg
generate difficulty toMsg =
    post "/api/generate"
        (Encode.object [ ( "difficulty", Encode.string difficulty ) ])
        puzzleDecoder
        toMsg


check : Puzzle -> (Result Error CheckResult -> msg) -> Cmd msg
check puzzle toMsg =
    post "/api/check" (encodePuzzle puzzle) checkDecoder toMsg


hint : Puzzle -> (Result Error Hint -> msg) -> Cmd msg
hint puzzle toMsg =
    post "/api/hint" (encodePuzzle puzzle) hintDecoder toMsg


solve : Puzzle -> (Result Error Puzzle -> msg) -> Cmd msg
solve puzzle toMsg =
    post "/api/solve" (encodePuzzle puzzle) puzzleDecoder toMsg


post : String -> Encode.Value -> Decoder a -> (Result Error a -> msg) -> Cmd msg
post url body decoder toMsg =
    Http.post
        { url = url
        , body = Http.jsonBody body
        , expect = expectJson toMsg decoder
        }


{-| Como `Http.expectJson`, mas lê o campo `detail` das respostas de erro do
FastAPI para mostrar a explicação do backend.
-}
expectJson : (Result Error a -> msg) -> Decoder a -> Http.Expect msg
expectJson toMsg decoder =
    Http.expectStringResponse toMsg <|
        \response ->
            case response of
                Http.GoodStatus_ _ body ->
                    Decode.decodeString decoder body
                        |> Result.mapError (\_ -> Failed)

                Http.BadStatus_ metadata body ->
                    case Decode.decodeString (Decode.field "detail" Decode.string) body of
                        Ok detail ->
                            Err (Rejected detail)

                        Err _ ->
                            -- O proxy do Vite responde 502/503/504 quando o
                            -- backend está desligado.
                            if List.member metadata.statusCode [ 502, 503, 504 ] then
                                Err Offline

                            else
                                Err Failed

                Http.NetworkError_ ->
                    Err Offline

                Http.Timeout_ ->
                    Err Offline

                Http.BadUrl_ _ ->
                    Err Failed


errorText : Error -> String
errorText error =
    case error of
        Offline ->
            "Sem conexão com a API na porta 8000."

        Rejected detail ->
            detail

        Failed ->
            "Não foi possível completar a operação. Tente de novo."



-- JSON


gridDecoder : Decoder Grid
gridDecoder =
    Decode.list (Decode.list Decode.int)


puzzleDecoder : Decoder Puzzle
puzzleDecoder =
    Decode.map2 Puzzle
        (Decode.field "regions" gridDecoder)
        (Decode.field "board" gridDecoder)


outcomeDecoder : Decoder Outcome
outcomeDecoder =
    Decode.string
        |> Decode.map
            (\status ->
                case status of
                    "venceu" ->
                        Won

                    "conflito" ->
                        Conflict

                    _ ->
                        Incomplete
            )


checkDecoder : Decoder CheckResult
checkDecoder =
    Decode.map2 CheckResult
        (Decode.field "status" outcomeDecoder)
        (Decode.field "conflicts"
            (Decode.list
                (Decode.map2 Tuple.pair
                    (Decode.index 0 Decode.int)
                    (Decode.index 1 Decode.int)
                )
            )
        )


hintDecoder : Decoder Hint
hintDecoder =
    Decode.map3 Hint
        (Decode.field "row" Decode.int)
        (Decode.field "col" Decode.int)
        (Decode.field "value" Decode.int)


encodeGrid : Grid -> Encode.Value
encodeGrid grid =
    Encode.list (Encode.list Encode.int) grid


encodePuzzle : Puzzle -> Encode.Value
encodePuzzle puzzle =
    Encode.object
        [ ( "regions", encodeGrid puzzle.regions )
        , ( "board", encodeGrid puzzle.board )
        ]
