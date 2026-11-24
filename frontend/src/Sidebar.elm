module Sidebar exposing (Tone(..), view)

{-| Página da direita do álbum: linha de status, ações (Dica, Resolver,
Reiniciar), regras ilustradas e atalhos de teclado.
-}

import Html exposing (Html, button, div, hr, kbd, li, p, span, strong, text, ul)
import Html.Attributes exposing (attribute, class, disabled, id, type_)
import Html.Events exposing (onClick)
import Icons exposing (Icon)


{-| Tom da linha de status. Conflito e erro sempre vêm com ícone.
-}
type Tone
    = Neutral
    | Conflict
    | Failure
    | Win


type alias Config msg =
    { tone : Tone
    , status : String
    , announce : String
    , retry : Maybe msg
    , onHint : msg
    , onSolve : msg
    , onReset : msg
    , helpDisabled : Bool
    , resetDisabled : Bool
    , solving : Bool
    }


view : Config msg -> Html msg
view config =
    div [ class "pp-side paper" ]
        [ viewStatus config
        , p [ class "sr-only", attribute "aria-live" "polite" ] [ text config.announce ]
        , viewActions config
        , hr [ class "divider" ] []
        , viewRules
        , p [ class "pp-kbd", id "pp-kbd" ]
            [ text "No teclado, as "
            , kbd [] [ text "setas" ]
            , text " andam pelas casas, "
            , kbd [] [ text "Espaço" ]
            , text " troca a casa e "
            , kbd [] [ text "Delete" ]
            , text " limpa."
            ]
        ]


viewStatus : Config msg -> Html msg
viewStatus config =
    let
        ( modifier, icon ) =
            case config.tone of
                Neutral ->
                    ( "", Nothing )

                Conflict ->
                    ( " status--conflict", Just Icons.Alerta )

                Failure ->
                    ( " status--error", Just Icons.SemRede )

                Win ->
                    ( " status--win", Nothing )
    in
    div [ class ("status" ++ modifier) ]
        (List.filterMap identity
            [ Maybe.map (Icons.view "icon") icon
            , Just (span [] [ text config.status ])
            , Maybe.map
                (\retry -> button [ class "btn", type_ "button", onClick retry ] [ text "Tentar de novo" ])
                config.retry
            ]
        )


viewActions : Config msg -> Html msg
viewActions config =
    div [ class "actions" ]
        [ action "btn" Icons.Dica "Dica" config.onHint config.helpDisabled False
        , action "btn"
            Icons.Resolver
            (if config.solving then
                "Resolvendo…"

             else
                "Resolver"
            )
            config.onSolve
            config.helpDisabled
            config.solving
        , action "btn btn--ghost" Icons.Reiniciar "Reiniciar" config.onReset config.resetDisabled False
        ]


action : String -> Icon -> String -> msg -> Bool -> Bool -> Html msg
action classes icon label msg off busy =
    button
        [ class classes
        , type_ "button"
        , disabled off
        , attribute "aria-busy"
            (if busy then
                "true"

             else
                "false"
            )
        , onClick msg
        ]
        [ Icons.view "icon" icon, text label ]


viewRules : Html msg
viewRules =
    ul [ class "rules" ]
        [ rule "region-1"
            [ span [ class "piece", attribute "aria-hidden" "true" ] [ text "🐶" ] ]
            "1 toque"
            " cola um puppy. Um por linha, coluna e região."
        , rule "region-3"
            [ Icons.view "mark-x" Icons.X ]
            "2 toques"
            " marcam onde não cabe puppy. O 3º limpa a casa."
        , rule "region-2 is-conflict"
            [ span [ class "piece", attribute "aria-hidden" "true" ] [ text "🐕" ] ]
            "Sem encostar"
            ", nem na diagonal."
        ]


rule : String -> List (Html msg) -> String -> String -> Html msg
rule region sample lead rest =
    li [ class "rules__item" ]
        [ span [ class ("cell cell--mini n-1 " ++ region) ] sample
        , span [] [ strong [] [ text lead ], text rest ]
        ]
