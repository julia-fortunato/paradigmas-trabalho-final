module Board exposing (Key(..), Mode(..), cellId, navigate, view)

{-| O tabuleiro como página do álbum: regiões em tons pastel separadas por
picote, e cada puppy colado como uma figurinha levemente torta.

O teclado segue o padrão de grade: só a casa em foco entra no Tab, as setas
andam pelas casas, Espaço/Enter troca a casa (clique nativo do botão) e
Delete/Backspace limpa.

-}

import Grid exposing (Cell(..))
import Html exposing (Html, button, div, span, text)
import Html.Attributes exposing (attribute, class, classList, disabled, id, tabindex, type_)
import Html.Events exposing (onClick, onFocus, preventDefaultOn)
import Icons
import Json.Decode as Decode
import Regions


{-| Em que situação o tabuleiro está.

  - `Loading`: o Prolog está gerando; casas viram esqueleto.
  - `Offline`: a API não respondeu; casas apagadas.
  - `Playing`: casas respondem a cliques.
  - `Locked`: solução revelada; casas só mostram o resultado.

-}
type Mode
    = Loading
    | Offline
    | Playing
    | Locked


type alias State =
    { size : Int
    , regions : List (List Int)
    , board : List (List Cell)
    , fixed : List (List Cell)
    , conflicts : List ( Int, Int )
    , hint : Maybe ( Int, Int )
    , focus : ( Int, Int )
    , mode : Mode
    , busy : Bool
    }


type alias Events msg =
    { press : Int -> Int -> msg
    , focus : Int -> Int -> msg
    , key : Key -> msg
    }


cellId : Int -> Int -> String
cellId row col =
    "cell-" ++ String.fromInt row ++ "-" ++ String.fromInt col


view : State -> Events msg -> Html msg
view state events =
    let
        skeleton =
            state.mode == Loading || state.mode == Offline
    in
    div
        [ classList
            [ ( "board", True )
            , ( "n-" ++ String.fromInt state.size, True )
            , ( "is-loading", skeleton )
            , ( "is-error", state.mode == Offline )
            ]
        , attribute "role" "grid"
        , attribute "aria-label" ("Tabuleiro " ++ String.fromInt state.size ++ " por " ++ String.fromInt state.size)
        , attribute "aria-describedby" "pp-kbd"
        , attribute "aria-busy"
            (if state.mode == Loading || state.busy then
                "true"

             else
                "false"
            )
        , preventDefaultOn "keydown" (keyDecoder events.key)
        ]
        (List.map (viewRow state events) (List.range 0 (state.size - 1)))


viewRow : State -> Events msg -> Int -> Html msg
viewRow state events row =
    div [ class "pp-row", attribute "role" "row" ]
        (List.map (viewCell state events row) (List.range 0 (state.size - 1)))


viewCell : State -> Events msg -> Int -> Int -> Html msg
viewCell state events row col =
    let
        skeleton =
            state.mode == Loading || state.mode == Offline

        region =
            Grid.at row col state.regions |> Maybe.withDefault 0

        value =
            Grid.at row col state.board |> Maybe.withDefault Empty

        regionAt r c =
            if r < 0 || c < 0 || r >= state.size || c >= state.size then
                0

            else
                Grid.at r c state.regions |> Maybe.withDefault 0

        -- Picote: borda do tabuleiro (o-*) ou divisa com outra região (e-*).
        edge side r c onBorder =
            if onBorder then
                [ "o-" ++ side ]

            else if regionAt r c /= region then
                [ "e-" ++ side ]

            else
                []

        conflict =
            List.member ( row, col ) state.conflicts

        hinted =
            state.hint == Just ( row, col )

        fixed =
            state.mode == Locked || Grid.at row col state.fixed == Just Puppy

        classes =
            if skeleton then
                "cell"

            else
                String.join " " <|
                    [ "cell"
                    , "region-" ++ String.fromInt region
                    , "t" ++ String.fromInt (modBy 5 (row * 3 + col * 7) + 1)
                    ]
                        ++ edge "t" (row - 1) col (row == 0)
                        ++ edge "l" row (col - 1) (col == 0)
                        ++ edge "b" (row + 1) col (row == state.size - 1)
                        ++ edge "r" row (col + 1) (col == state.size - 1)
                        ++ flag (value == Puppy) "is-puppy"
                        ++ flag (value == Excluded) "is-excluded"
                        ++ flag conflict "is-conflict"
                        ++ flag hinted "is-hint"
                        ++ flag fixed "is-fixed"

        label =
            if state.mode == Loading then
                "Carregando"

            else
                String.concat
                    [ "Linha " ++ String.fromInt (row + 1)
                    , ", coluna " ++ String.fromInt (col + 1)
                    , ", região " ++ Regions.name region
                    , case value of
                        Puppy ->
                            ", puppy"

                        Excluded ->
                            ", marcada com ×"

                        Empty ->
                            ", vazia"
                    , if conflict then
                        ", em conflito"

                      else
                        ""
                    , if hinted then
                        ", dica"

                      else
                        ""
                    ]
    in
    button
        [ class classes
        , id (cellId row col)
        , attribute "role" "gridcell"
        , type_ "button"
        , attribute "aria-label" label
        , tabindex
            (if state.focus == ( row, col ) then
                0

             else
                -1
            )
        , disabled skeleton
        , onClick (events.press row col)
        , onFocus (events.focus row col)
        ]
        (if skeleton then
            []

         else
            case value of
                Puppy ->
                    [ span [ class "piece", attribute "aria-hidden" "true" ] [ text (Regions.breed region) ] ]

                Excluded ->
                    [ Icons.view "mark-x" Icons.X ]

                Empty ->
                    []
        )


flag : Bool -> String -> List String
flag on name =
    if on then
        [ name ]

    else
        []


{-| Atalhos de teclado do tabuleiro.

  - `Step dr dc`: setas, uma casa na direção dada.
  - `Home ctrl` / `End ctrl`: começo ou fim da linha (com Ctrl, do tabuleiro).
  - `Clear`: Delete ou Backspace limpa a casa em foco.

-}
type Key
    = Step Int Int
    | Home Bool
    | End Bool
    | Clear


{-| Para onde o foco vai depois de um atalho de navegação. Fica no `update`
(e não no decoder) para sempre partir do foco atual do modelo, mesmo com
teclas apertadas muito rápido.
-}
navigate : Int -> ( Int, Int ) -> Key -> ( Int, Int )
navigate size ( row, col ) key =
    let
        last =
            size - 1

        inside ( r, c ) =
            ( clamp 0 last r, clamp 0 last c )
    in
    case key of
        Step dr dc ->
            inside ( row + dr, col + dc )

        Home ctrl ->
            if ctrl then
                ( 0, 0 )

            else
                ( row, 0 )

        End ctrl ->
            if ctrl then
                ( last, last )

            else
                ( row, last )

        Clear ->
            ( row, col )


{-| Teclas sem atalho seguem o comportamento normal do navegador (por isso o
decoder falha para elas).
-}
keyDecoder : (Key -> msg) -> Decode.Decoder ( msg, Bool )
keyDecoder toMsg =
    Decode.map2 Tuple.pair
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        |> Decode.andThen
            (\( key, ctrl ) ->
                case key of
                    "ArrowUp" ->
                        Decode.succeed (Step -1 0)

                    "ArrowDown" ->
                        Decode.succeed (Step 1 0)

                    "ArrowLeft" ->
                        Decode.succeed (Step 0 -1)

                    "ArrowRight" ->
                        Decode.succeed (Step 0 1)

                    "Home" ->
                        Decode.succeed (Home ctrl)

                    "End" ->
                        Decode.succeed (End ctrl)

                    "Delete" ->
                        Decode.succeed Clear

                    "Backspace" ->
                        Decode.succeed Clear

                    _ ->
                        Decode.fail "tecla sem atalho"
            )
        |> Decode.map (\key -> ( toMsg key, True ))
