module Main exposing (main)

import Browser
import Grid
import Html exposing (Html, button, div, h1, h2, p, span, text)
import Html.Attributes exposing (attribute, class, disabled, style, title)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import List


type alias Grid =
    List (List Int)


type alias Puzzle =
    { regions : Grid, board : Grid }


type alias Model =
    { puzzle : Maybe Puzzle
    , original : Maybe Puzzle
    , difficulty : String
    , status : String
    , conflicts : List ( Int, Int )
    , busy : Bool
    , version : Int
    }


type Msg
    = NewGame String
    | GotGame Int (Result Http.Error Puzzle)
    | ClickCell Int Int
    | GotCheck Int (Result Http.Error CheckResult)
    | AskHint
    | GotHint Int (Result Http.Error Hint)
    | AskSolve
    | GotSolution Int (Result Http.Error Puzzle)
    | Reset


type alias CheckResult =
    { status : String, conflicts : List ( Int, Int ) }


type alias Hint =
    { row : Int, col : Int, value : Int }


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }


init : ( Model, Cmd Msg )
init =
    ( { puzzle = Nothing
      , original = Nothing
      , difficulty = "easy"
      , status = "Gerando tabuleiro..."
      , conflicts = []
      , busy = True
      , version = 1
      }
    , generate "easy" 1
    )


gridDecoder : Decoder Grid
gridDecoder =
    Decode.list (Decode.list Decode.int)


puzzleDecoder : Decoder Puzzle
puzzleDecoder =
    Decode.map2 Puzzle
        (Decode.field "regions" gridDecoder)
        (Decode.field "board" gridDecoder)


checkDecoder : Decoder CheckResult
checkDecoder =
    Decode.map2 CheckResult
        (Decode.field "status" Decode.string)
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


generate : String -> Int -> Cmd Msg
generate difficulty version =
    Http.post
        { url = "/api/generate"
        , body = Http.jsonBody (Encode.object [ ( "difficulty", Encode.string difficulty ) ])
        , expect = Http.expectJson (GotGame version) puzzleDecoder
        }


check : Puzzle -> Int -> Cmd Msg
check puzzle version =
    Http.post
        { url = "/api/check"
        , body = Http.jsonBody (encodePuzzle puzzle)
        , expect = Http.expectJson (GotCheck version) checkDecoder
        }


hint : Puzzle -> Int -> Cmd Msg
hint puzzle version =
    Http.post
        { url = "/api/hint"
        , body = Http.jsonBody (encodePuzzle puzzle)
        , expect = Http.expectJson (GotHint version) hintDecoder
        }


solve : Puzzle -> Int -> Cmd Msg
solve puzzle version =
    Http.post
        { url = "/api/solve"
        , body = Http.jsonBody (encodePuzzle puzzle)
        , expect = Http.expectJson (GotSolution version) puzzleDecoder
        }


errorText : Http.Error -> String
errorText error =
    case error of
        Http.BadStatus 422 ->
            "Esta jogada não tem solução. Confira os puppies e as exclusões."

        Http.BadStatus _ ->
            "A API retornou um erro. Tente novamente."

        Http.NetworkError ->
            "Sem conexão com a API na porta 8000."

        _ ->
            "Não foi possível completar a operação."


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewGame difficulty ->
            let
                version =
                    model.version + 1
            in
            ( { model | busy = True, difficulty = difficulty, status = "Gerando tabuleiro...", version = version }
            , generate difficulty version
            )

        GotGame version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case result of
                    Ok puzzle ->
                        ( { model | puzzle = Just puzzle, original = Just puzzle, busy = False, status = "Encontre um puppy em cada linha, coluna e região.", conflicts = [] }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | busy = False, status = errorText error }, Cmd.none )

        ClickCell row col ->
            case ( model.puzzle, model.original ) of
                ( Just puzzle, Just original ) ->
                    if model.busy || Grid.at row col original.board == 1 then
                        ( model, Cmd.none )

                    else
                        let
                            old =
                                Grid.at row col puzzle.board

                            next =
                                if old == 0 then
                                    1

                                else if old == 1 then
                                    -1

                                else
                                    0

                            updated =
                                { puzzle | board = Grid.setCell row col next puzzle.board }

                            version =
                                model.version + 1
                        in
                        ( { model | puzzle = Just updated, status = "Verificando...", conflicts = [], version = version }
                        , check updated version
                        )

                _ ->
                    ( model, Cmd.none )

        GotCheck version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case result of
                    Ok outcome ->
                        let
                            message =
                                case outcome.status of
                                    "venceu" ->
                                        "Parabéns! Você encontrou todos os puppies."

                                    "conflito" ->
                                        "Há puppies em conflito. Revise as casas destacadas."

                                    _ ->
                                        "Continue: um puppy por linha, coluna e região."
                        in
                        ( { model | status = message, conflicts = outcome.conflicts }, Cmd.none )

                    Err error ->
                        ( { model | status = errorText error }, Cmd.none )

        AskHint ->
            case model.puzzle of
                Just puzzle ->
                    ( { model | busy = True, status = "Buscando dica..." }, hint puzzle model.version )

                Nothing ->
                    ( model, Cmd.none )

        GotHint version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case ( result, model.puzzle ) of
                    ( Ok clue, Just puzzle ) ->
                        let
                            updated =
                                { puzzle | board = Grid.setCell clue.row clue.col clue.value puzzle.board }

                            nextVersion =
                                model.version + 1
                        in
                        ( { model | puzzle = Just updated, busy = False, status = "Um puppy foi revelado.", version = nextVersion }
                        , check updated nextVersion
                        )

                    ( Err error, _ ) ->
                        ( { model | busy = False, status = errorText error }, Cmd.none )

                    _ ->
                        ( { model | busy = False }, Cmd.none )

        AskSolve ->
            case model.puzzle of
                Just puzzle ->
                    ( { model | busy = True, status = "Resolvendo..." }, solve puzzle model.version )

                Nothing ->
                    ( model, Cmd.none )

        GotSolution version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case result of
                    Ok puzzle ->
                        ( { model | puzzle = Just puzzle, busy = False, conflicts = [], status = "Solução revelada." }, Cmd.none )

                    Err error ->
                        ( { model | busy = False, status = errorText error }, Cmd.none )

        Reset ->
            case model.original of
                Just original ->
                    ( { model | puzzle = Just original, busy = False, conflicts = [], status = "Tabuleiro reiniciado.", version = model.version + 1 }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "app" ]
        [ div [ class "topline" ] [ span [] [ text "PROLOG + ELM" ], span [] [ text "PUZZLES LÓGICOS" ] ]
        , div [ class "hero" ]
            [ div []
                [ h1 [] [ text "Puppies" ]
                , p [ class "subtitle" ] [ text "Cada puppy quer seu próprio espaço." ]
                ]
            , div [ class "difficulty" ]
                [ button [ class (if model.difficulty == "easy" then "selected" else ""), onClick (NewGame "easy"), disabled model.busy ] [ text "Fácil · 5×5" ]
                , button [ class (if model.difficulty == "hard" then "selected" else ""), onClick (NewGame "hard"), disabled model.busy ] [ text "Difícil · 8×8" ]
                ]
            ]
        , div [ class "content" ]
            [ div [ class "game-panel" ]
                [ case model.puzzle of
                    Just puzzle ->
                        viewBoard model puzzle

                    Nothing ->
                        div [ class "empty-board" ] [ text model.status ]
                , p [ class "status", attribute "role" "status" ] [ text model.status ]
                , div [ class "actions" ]
                    [ button [ onClick AskHint, disabled (model.busy || model.puzzle == Nothing) ] [ text "Dica" ]
                    , button [ onClick AskSolve, disabled (model.busy || model.puzzle == Nothing) ] [ text "Resolver" ]
                    , button [ onClick Reset, disabled (model.busy || model.original == Nothing) ] [ text "Reiniciar" ]
                    ]
                ]
            , div [ class "rules" ]
                [ span [ class "eyebrow" ] [ text "COMO JOGAR" ]
                , h2 [] [ text "Um lugar para cada um." ]
                , p [] [ text "Coloque exatamente um puppy em cada linha, coluna e região colorida." ]
                , p [] [ text "Puppies não podem se tocar, nem na diagonal. Diagonais distantes são permitidas." ]
                , div [ class "legend" ]
                    [ span [] [ text "1 clique", span [ class "legend-icon" ] [ text "🐶" ], text "Puppy" ]
                    , span [] [ text "2 cliques", span [ class "legend-icon" ] [ text "×" ], text "Excluir" ]
                    , span [] [ text "3 cliques", span [ class "legend-icon" ] [ text "·" ], text "Limpar" ]
                    ]
                ]
            ]
        ]


viewBoard : Model -> Puzzle -> Html Msg
viewBoard model puzzle =
    let
        size =
            List.length puzzle.board
    in
    div [ class "board", style "grid-template-columns" ("repeat(" ++ String.fromInt size ++ ", 1fr)") ]
        (List.concat
            (List.indexedMap
                (\row cells ->
                    List.indexedMap (viewCell model puzzle size row) cells
                )
                puzzle.board
            )
        )


viewCell : Model -> Puzzle -> Int -> Int -> Int -> Int -> Html Msg
viewCell model puzzle size row col value =
    let
        region =
            Grid.at row col puzzle.regions

        boundary directionRow directionCol =
            if directionRow < 0 || directionCol < 0 || directionRow >= size || directionCol >= size || Grid.at directionRow directionCol puzzle.regions /= region then
                "2px solid #253c50"

            else
                "1px solid rgba(37,60,80,.16)"

        conflict =
            List.member ( row, col ) model.conflicts

        label =
            "Linha " ++ String.fromInt (row + 1) ++ ", coluna " ++ String.fromInt (col + 1)
    in
    button
        [ class ("cell region-" ++ String.fromInt (modBy 8 region) ++ (if conflict then " conflict" else ""))
        , style "border-top" (boundary (row - 1) col)
        , style "border-left" (boundary row (col - 1))
        , style "border-right" (if col == size - 1 then "2px solid #253c50" else "0")
        , style "border-bottom" (if row == size - 1 then "2px solid #253c50" else "0")
        , attribute "aria-label" label
        , title label
        , onClick (ClickCell row col)
        , disabled model.busy
        ]
        [ text
            (if value == 1 then
                "🐶"

             else if value == -1 then
                "×"

             else
                ""
            )
        ]
