module Regions exposing (Seal(..), breed, name, seals)

{-| Dados de apresentação das regiões coloridas: o nome de cada tinta, a
raça do puppy que cola nela e o selo que mostra se a região já tem puppy.

-}

import Grid


{-| Nome da tinta de cada região, na ordem fixa do álbum (região 1 é azul).
-}
name : Int -> String
name region =
    pick region
        [ "Azul", "Coral", "Amarelo", "Verde", "Lilás", "Rosa", "Laranja", "Turquesa", "Areia", "Gelo" ]
        ""


{-| Raça da figurinha de cada região, repetindo a partir da sexta.
-}
breed : Int -> String
breed region =
    pick (modBy 5 (region - 1) + 1)
        [ "🐶", "🐕", "🐩", "🦮", "🐕\u{200D}🦺" ]
        "🐶"


pick : Int -> List String -> String -> String
pick index list fallback =
    list
        |> List.drop (index - 1)
        |> List.head
        |> Maybe.withDefault fallback


{-| Estado do selo de uma região: sem puppy, com um puppy ou com puppies demais.
-}
type Seal
    = Empty
    | Filled
    | Crowded


{-| Um selo por região (1 a N), contando os puppies colados em cada uma.
-}
seals : Int -> List (List Int) -> List (List Int) -> List ( Int, Seal )
seals size regions board =
    let
        puppiesIn region =
            List.map2
                (List.map2
                    (\r v ->
                        if r == region && v == 1 then
                            1

                        else
                            0
                    )
                )
                regions
                board
                |> Grid.count 1

        seal region =
            case puppiesIn region of
                0 ->
                    ( region, Empty )

                1 ->
                    ( region, Filled )

                _ ->
                    ( region, Crowded )
    in
    List.map seal (List.range 1 size)
