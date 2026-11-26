module Main exposing (main)

{-| Puppies: um puppy por linha, coluna e região colorida, sem que dois se
encostem. O tabuleiro é gerado, conferido e resolvido pelo Prolog (via
FastAPI); o Elm cuida só da interface, vestida como um álbum de figurinhas.
-}

import Api exposing (Puzzle)
import Board
import Browser
import Browser.Dom
import Grid exposing (Cell(..))
import Html exposing (Html, button, div, h1, header, main_, section, span, text)
import Html.Attributes exposing (attribute, class, classList, type_)
import Html.Events exposing (onClick)
import Hud
import Icons
import Sidebar exposing (Tone(..))
import Task
import Time
import Victory



-- MODELO


{-| Em que fase está a partida.
-}
type Phase
    = Generating
    | GenerationFailed Api.Error
    | Playing
    | Solved


{-| Pedido de ajuda em andamento no backend.
-}
type Request
    = Hinting
    | Solving


type alias Model =
    { puzzle : Maybe Puzzle
    , original : Maybe Puzzle
    , difficulty : String
    , phase : Phase
    , outcome : Api.Outcome
    , conflicts : List ( Int, Int )
    , problem : Maybe Api.Error
    , request : Maybe Request
    , version : Int
    , dark : Bool
    , seconds : Int
    , moves : Int
    , hints : Int
    , started : Bool
    , hintAt : Maybe ( Int, Int )
    , focus : ( Int, Int )
    , winOpen : Bool
    , said : String
    , announce : String
    }


type Msg
    = NewGame String
    | GotGame Int (Result Api.Error Puzzle)
    | PressCell Int Int
    | FocusCell Int Int
    | BoardKey Board.Key
    | GotCheck Int (Result Api.Error Api.CheckResult)
    | AskHint
    | GotHint Int (Result Api.Error Api.Hint)
    | AskSolve
    | GotSolution Int (Result Api.Error Puzzle)
    | Reset
    | ToggleTheme
    | CloseVictory
    | Tick
    | NoOp


main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : ( Model, Cmd Msg )
init =
    startGame "easy"
        { puzzle = Nothing
        , original = Nothing
        , difficulty = "easy"
        , phase = Generating
        , outcome = Api.Incomplete
        , conflicts = []
        , problem = Nothing
        , request = Nothing
        , version = 0
        , dark = False
        , seconds = 0
        , moves = 0
        , hints = 0
        , started = False
        , hintAt = Nothing
        , focus = ( 0, 0 )
        , winOpen = False
        , said = ""
        , announce = ""
        }


{-| O relógio só anda com a partida em curso.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    if model.phase == Playing && model.started && not (won model) then
        Time.every 1000 (\_ -> Tick)

    else
        Sub.none



-- CONSULTAS


won : Model -> Bool
won model =
    model.phase == Playing && model.outcome == Api.Won


{-| Lado do tabuleiro: o do puzzle carregado ou o da dificuldade escolhida.
-}
boardSize : Model -> Int
boardSize model =
    case model.puzzle of
        Just puzzle ->
            List.length puzzle.board

        Nothing ->
            if model.difficulty == "hard" then
                8

            else
                5


puppiesLeft : Model -> Int
puppiesLeft model =
    case model.puzzle of
        Just puzzle ->
            boardSize model - Grid.count Puppy puzzle.board

        Nothing ->
            boardSize model



-- ATUALIZAÇÃO


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewGame difficulty ->
            startGame difficulty model

        GotGame version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case result of
                    Ok puzzle ->
                        ( { model
                            | puzzle = Just puzzle
                            , original = Just puzzle
                            , phase = Playing
                            , announce = "Tabuleiro pronto. Um puppy por linha, coluna e região."
                          }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | phase = GenerationFailed error, announce = Api.errorText error }
                        , Cmd.none
                        )

        PressCell row col ->
            case model.puzzle of
                Just puzzle ->
                    let
                        current =
                            Grid.at row col puzzle.board |> Maybe.withDefault Empty
                    in
                    place row col (Grid.nextCell current) model

                Nothing ->
                    ( model, Cmd.none )

        FocusCell row col ->
            ( { model | focus = ( row, col ) }, Cmd.none )

        BoardKey Board.Clear ->
            let
                ( row, col ) =
                    model.focus
            in
            place row col Empty model

        BoardKey key ->
            let
                ( row, col ) =
                    Board.navigate (boardSize model) model.focus key
            in
            ( { model | focus = ( row, col ) }, focusOn (Board.cellId row col) )

        GotCheck version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case result of
                    Ok outcome ->
                        let
                            checked =
                                { model
                                    | outcome = outcome.outcome
                                    , conflicts = outcome.conflicts
                                    , problem = Nothing
                                    , winOpen = outcome.outcome == Api.Won && model.phase == Playing
                                }
                        in
                        ( { checked | announce = String.trim (model.said ++ " " ++ statusText checked) }
                        , if checked.winOpen then
                            focusOn Victory.againId

                          else
                            Cmd.none
                        )

                    Err error ->
                        ( { model | problem = Just error, announce = Api.errorText error }, Cmd.none )

        AskHint ->
            case model.puzzle of
                Just puzzle ->
                    ( { model | request = Just Hinting, problem = Nothing }
                    , Api.hint puzzle (GotHint model.version)
                    )

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

                            where_ =
                                "linha " ++ String.fromInt (clue.row + 1) ++ ", coluna " ++ String.fromInt (clue.col + 1)

                            nextVersion =
                                model.version + 1
                        in
                        ( { model
                            | puzzle = Just updated
                            , request = Nothing
                            , hints = model.hints + 1
                            , hintAt = Just ( clue.row, clue.col )
                            , started = True
                            , focus = ( clue.row, clue.col )
                            , version = nextVersion
                            , said =
                                case clue.value of
                                    Puppy ->
                                        "Dica: puppy na " ++ where_ ++ "."

                                    Excluded ->
                                        "Dica: a " ++ where_ ++ " não tem puppy."

                                    Empty ->
                                        "Dica: casa limpa na " ++ where_ ++ "."
                          }
                        , Api.check updated (GotCheck nextVersion)
                        )

                    ( Err error, _ ) ->
                        ( { model | request = Nothing, problem = Just error, announce = Api.errorText error }
                        , Cmd.none
                        )

                    _ ->
                        ( { model | request = Nothing }, Cmd.none )

        AskSolve ->
            case model.puzzle of
                Just puzzle ->
                    ( { model | request = Just Solving, problem = Nothing }
                    , Api.solve puzzle (GotSolution model.version)
                    )

                Nothing ->
                    ( model, Cmd.none )

        GotSolution version result ->
            if version /= model.version then
                ( model, Cmd.none )

            else
                case result of
                    Ok puzzle ->
                        ( { model
                            | puzzle = Just puzzle
                            , phase = Solved
                            , request = Nothing
                            , conflicts = []
                            , hintAt = Nothing
                            , announce = "Solução revelada. Reinicie para tentar de novo."
                          }
                        , Cmd.none
                        )

                    Err error ->
                        ( { model | request = Nothing, problem = Just error, announce = Api.errorText error }
                        , Cmd.none
                        )

        Reset ->
            case model.original of
                Just original ->
                    ( { model
                        | puzzle = Just original
                        , phase = Playing
                        , outcome = Api.Incomplete
                        , conflicts = []
                        , problem = Nothing
                        , request = Nothing
                        , version = model.version + 1
                        , seconds = 0
                        , moves = 0
                        , hints = 0
                        , started = False
                        , hintAt = Nothing
                        , winOpen = False
                        , said = ""
                        , announce = "Tabuleiro reiniciado."
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        ToggleTheme ->
            ( { model | dark = not model.dark }, Cmd.none )

        CloseVictory ->
            let
                ( row, col ) =
                    model.focus
            in
            ( { model | winOpen = False }, focusOn (Board.cellId row col) )

        Tick ->
            ( { model | seconds = model.seconds + 1 }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


{-| Pede um tabuleiro novo ao Prolog e zera o placar.
-}
startGame : String -> Model -> ( Model, Cmd Msg )
startGame difficulty model =
    let
        version =
            model.version + 1

        size =
            boardSize { model | puzzle = Nothing, difficulty = difficulty }
    in
    ( { model
        | puzzle = Nothing
        , original = Nothing
        , difficulty = difficulty
        , phase = Generating
        , outcome = Api.Incomplete
        , conflicts = []
        , problem = Nothing
        , request = Nothing
        , version = version
        , seconds = 0
        , moves = 0
        , hints = 0
        , started = False
        , hintAt = Nothing
        , focus = ( 0, 0 )
        , winOpen = False
        , said = ""
        , announce = "Preparando um tabuleiro " ++ String.fromInt size ++ " por " ++ String.fromInt size ++ "."
      }
    , Api.generate difficulty (GotGame version)
    )


{-| Coloca um valor numa casa e pede ao Prolog para conferir o tabuleiro.
-}
place : Int -> Int -> Cell -> Model -> ( Model, Cmd Msg )
place row col value model =
    case ( model.puzzle, model.original ) of
        ( Just puzzle, Just original ) ->
            let
                locked =
                    model.phase /= Playing || won model || model.request /= Nothing

                given =
                    Grid.at row col original.board == Just Puppy

                unchanged =
                    Grid.at row col puzzle.board == Just value
            in
            if locked || given || unchanged then
                ( model, Cmd.none )

            else
                let
                    updated =
                        { puzzle | board = Grid.setCell row col value puzzle.board }

                    version =
                        model.version + 1

                    position =
                        "linha " ++ String.fromInt (row + 1) ++ ", coluna " ++ String.fromInt (col + 1)
                in
                ( { model
                    | puzzle = Just updated
                    , version = version
                    , moves = model.moves + 1
                    , started = True
                    , hintAt = Nothing
                    , focus = ( row, col )
                    , problem = Nothing

                    -- Mantém a hachura só onde ainda há puppy até o Prolog responder.
                    , conflicts = List.filter (\( r, c ) -> Grid.at r c updated.board == Just Puppy) model.conflicts
                    , said =
                        case value of
                            Puppy ->
                                "Puppy colado na " ++ position ++ "."

                            Excluded ->
                                "Casa marcada com ×."

                            Empty ->
                                "Casa limpa."
                  }
                , Api.check updated (GotCheck version)
                )

        _ ->
            ( model, Cmd.none )


focusOn : String -> Cmd Msg
focusOn elementId =
    Task.attempt (\_ -> NoOp) (Browser.Dom.focus elementId)



-- VISUALIZAÇÃO


view : Model -> Html Msg
view model =
    div [ class "pp-wrap" ]
        [ div [ classList [ ( "pp", True ), ( "is-dark", model.dark ) ] ]
            [ viewBar model
            , main_ [ class "pp-spread" ]
                [ section [ class "pp-board", attribute "aria-label" "Página do tabuleiro" ]
                    [ viewBoard model
                    , if model.winOpen then
                        Victory.view
                            { size = boardSize model
                            , seconds = model.seconds
                            , moves = model.moves
                            , hints = model.hints
                            , onAgain = NewGame model.difficulty
                            , onClose = CloseVictory
                            }

                      else
                        text ""
                    ]
                , Hud.view
                    { seconds = model.seconds
                    , moves = model.moves
                    , size = boardSize model
                    , regions = Maybe.withDefault [] (Maybe.map .regions model.puzzle)
                    , board = Maybe.withDefault [] (Maybe.map .board model.puzzle)
                    }
                , viewSidebar model
                ]
            ]
        ]


viewBar : Model -> Html Msg
viewBar model =
    header [ class "bar pp-bar" ]
        [ h1 [ class "brand" ] [ text "Puppies" ]
        , div [ class "bar__end" ]
            [ div [ class "segmented", attribute "role" "group", attribute "aria-label" "Dificuldade" ]
                [ difficultyOption model "easy" "Fácil" "5×5"
                , difficultyOption model "hard" "Difícil" "8×8"
                ]
            , button
                [ class "btn btn--ghost btn--icon"
                , type_ "button"
                , attribute "aria-label"
                    (if model.dark then
                        "Usar tema claro"

                     else
                        "Usar tema escuro"
                    )
                , onClick ToggleTheme
                ]
                [ Icons.view "icon"
                    (if model.dark then
                        Icons.Sol

                     else
                        Icons.Lua
                    )
                ]
            ]
        ]


difficultyOption : Model -> String -> String -> String -> Html Msg
difficultyOption model difficulty label size =
    button
        [ class "segmented__option"
        , type_ "button"
        , attribute "aria-pressed"
            (if model.difficulty == difficulty then
                "true"

             else
                "false"
            )
        , onClick (NewGame difficulty)
        ]
        [ text (label ++ " "), span [ class "segmented__size" ] [ text size ] ]


viewBoard : Model -> Html Msg
viewBoard model =
    Board.view
        { size = boardSize model
        , regions = Maybe.withDefault [] (Maybe.map .regions model.puzzle)
        , board = Maybe.withDefault [] (Maybe.map .board model.puzzle)
        , fixed = Maybe.withDefault [] (Maybe.map .board model.original)
        , conflicts = model.conflicts
        , hint = model.hintAt
        , focus = model.focus
        , mode =
            case model.phase of
                Generating ->
                    Board.Loading

                GenerationFailed _ ->
                    Board.Offline

                Solved ->
                    Board.Locked

                Playing ->
                    if won model then
                        Board.Locked

                    else
                        Board.Playing
        , busy = model.request /= Nothing
        }
        { press = PressCell
        , focus = FocusCell
        , key = BoardKey
        }


viewSidebar : Model -> Html Msg
viewSidebar model =
    Sidebar.view
        { tone = statusTone model
        , status = statusText model
        , announce = model.announce
        , retry =
            case model.phase of
                GenerationFailed _ ->
                    Just (NewGame model.difficulty)

                _ ->
                    Nothing
        , onHint = AskHint
        , onSolve = AskSolve
        , onReset = Reset
        , helpDisabled = model.phase /= Playing || won model || model.request /= Nothing
        , resetDisabled = model.phase == Generating || model.original == Nothing
        , solving = model.request == Just Solving
        }


statusTone : Model -> Tone
statusTone model =
    case model.phase of
        GenerationFailed _ ->
            Failure

        Playing ->
            case ( model.problem, model.outcome ) of
                ( Just Api.Offline, _ ) ->
                    Failure

                ( Just _, _ ) ->
                    Conflict

                ( Nothing, Api.Won ) ->
                    Win

                ( Nothing, Api.Conflict ) ->
                    Conflict

                ( Nothing, Api.Incomplete ) ->
                    Neutral

        _ ->
            Neutral


statusText : Model -> String
statusText model =
    case model.phase of
        Generating ->
            "Preparando o tabuleiro…"

        GenerationFailed error ->
            Api.errorText error

        Solved ->
            "Solução revelada. Reinicie para tentar de novo."

        Playing ->
            case ( model.problem, model.outcome ) of
                ( Just error, _ ) ->
                    Api.errorText error

                ( Nothing, Api.Won ) ->
                    "Todos no lugar."

                ( Nothing, Api.Conflict ) ->
                    "Há puppies em conflito. Revise as casas hachuradas."

                ( Nothing, Api.Incomplete ) ->
                    case puppiesLeft model of
                        1 ->
                            "Falta 1 puppy."

                        left ->
                            if left == boardSize model then
                                "Um puppy por linha, coluna e região."

                            else
                                "Faltam " ++ String.fromInt left ++ " puppies."
