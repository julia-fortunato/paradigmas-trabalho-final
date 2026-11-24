module Grid exposing (at, count, setCell)

import List


at : Int -> Int -> List (List Int) -> Int
at row col grid =
    grid
        |> List.drop row
        |> List.head
        |> Maybe.withDefault []
        |> List.drop col
        |> List.head
        |> Maybe.withDefault 0


setCell : Int -> Int -> Int -> List (List Int) -> List (List Int)
setCell row col value grid =
    List.indexedMap
        (\r cells ->
            if r == row then
                List.indexedMap
                    (\c old ->
                        if c == col then
                            value

                        else
                            old
                    )
                    cells

            else
                cells
        )
        grid


{-| Quantas casas da grade têm o valor dado.
-}
count : Int -> List (List Int) -> Int
count value grid =
    grid
        |> List.concat
        |> List.filter ((==) value)
        |> List.length
