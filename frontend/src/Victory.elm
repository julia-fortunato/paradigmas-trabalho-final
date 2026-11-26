module Victory exposing (againId, view)

{-| Tela de vitória: a capa cobre a página do tabuleiro e o selo campeão
aparece num cartão, com o tempo, as jogadas e as dicas usadas.
-}

import Html exposing (Html, button, dd, div, dl, dt, h2, section, span, text)
import Html.Attributes exposing (attribute, class, id, type_)
import Html.Events exposing (onClick)
import Hud
import Icons


type alias Config msg =
    { size : Int
    , seconds : Int
    , moves : Int
    , hints : Int
    , onAgain : msg
    , onClose : msg
    }


{-| Id do botão "Jogar de novo", que recebe o foco quando a vitória abre.
-}
againId : String
againId =
    "pp-win-again"


view : Config msg -> Html msg
view config =
    div [ class "pp-win" ]
        [ section
            [ class "victory victory--card"
            , attribute "role" "dialog"
            , attribute "aria-labelledby" "pp-win-title"
            , attribute "aria-describedby" "pp-win-stats"
            ]
            [ div [ class ("champion r-" ++ String.fromInt config.size), attribute "aria-hidden" "true" ]
                [ div [ class "champion__disc" ] []
                , div [ class "champion__center" ] [ span [ class "champion__title" ] [ text "Campeão" ] ]
                ]
            , h2 [ class "victory__title", id "pp-win-title" ] [ text "Página completa." ]
            , dl [ class "victory__stats", id "pp-win-stats" ]
                [ stat "Tempo" (Hud.clock config.seconds)
                , stat "Jogadas" (String.fromInt config.moves)
                , stat "Dicas" (String.fromInt config.hints)
                ]
            , div [ class "actions" ]
                [ button [ class "btn btn--primary", type_ "button", id againId, onClick config.onAgain ]
                    [ Icons.view "icon" Icons.Reiniciar, text "Jogar de novo" ]
                , button [ class "btn btn--ghost", type_ "button", onClick config.onClose ]
                    [ text "Ver página" ]
                ]
            ]
        ]


stat : String -> String -> Html msg
stat label value =
    div [] [ dt [] [ text label ], dd [] [ text value ] ]
