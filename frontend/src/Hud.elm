module Hud exposing (clock, view)

{-| Placar do jogo: o pacotinho de figurinhas com tempo e jogadas, e os
selos das regiões mostrando quais já têm puppy.
-}

import Grid exposing (Cell)
import Html exposing (Html, div, li, p, span, text, ul)
import Html.Attributes exposing (attribute, class, id)
import Regions exposing (Seal(..))


type alias Stats =
    { seconds : Int
    , moves : Int
    , size : Int
    , regions : List (List Int)
    , board : List (List Cell)
    }


{-| Formata segundos como `mm:ss`.
-}
clock : Int -> String
clock seconds =
    pad (seconds // 60) ++ ":" ++ pad (modBy 60 seconds)


pad : Int -> String
pad n =
    String.padLeft 2 '0' (String.fromInt n)


view : Stats -> Html msg
view stats =
    div [ class "pp-hud" ]
        [ div [ class "armband pp-packet", attribute "role" "group", attribute "aria-label" "Placar" ]
            [ stat "Tempo" (clock stats.seconds)
            , stat "Jogadas" (String.fromInt stats.moves)
            ]
        , viewSeals stats
        ]


stat : String -> String -> Html msg
stat label value =
    div [ class "armband__stat" ]
        [ span [ class "armband__label" ] [ text label ]
        , span [ class "armband__value" ] [ text value ]
        ]


viewSeals : Stats -> Html msg
viewSeals stats =
    let
        seals =
            Regions.seals stats.size stats.regions stats.board

        filled =
            List.length (List.filter (\( _, seal ) -> seal == Filled) seals)
    in
    div [ class "pp-seals paper" ]
        [ div [ class "pp-seals__head" ]
            [ p [ class "pp-label", id "pp-seals-label" ] [ text "Regiões" ]
            , span [ class "pp-count" ]
                [ text (String.fromInt filled ++ " de " ++ String.fromInt stats.size) ]
            ]
        , ul [ class "rosettes", attribute "aria-labelledby" "pp-seals-label" ]
            (List.map viewSeal seals)
        ]


viewSeal : ( Int, Seal ) -> Html msg
viewSeal ( region, seal ) =
    let
        ( modifier, description ) =
            case seal of
                Empty ->
                    ( "", "sem puppy" )

                Filled ->
                    ( " is-filled", "com puppy" )

                Crowded ->
                    ( " is-conflict", "puppies demais" )
    in
    li [ class ("rosette region-" ++ String.fromInt region ++ modifier) ]
        [ span [ class "sr-only" ] [ text (Regions.name region ++ ": " ++ description) ] ]
