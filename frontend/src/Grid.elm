module Grid exposing
    ( Cell(..)
    , at
    , cellFromInt
    , cellToInt
    , count
    , nextCell
    , setCell
    )

{-| Representação das células do tabuleiro e operações puras sobre grades.

Usar o tipo algébrico `Cell` no lugar de inteiros soltos (`0`, `1`, `-1`) torna
estados inválidos irrepresentáveis no domínio e obriga todo `case` a tratar as
três possibilidades.

-}


type Cell
    = Empty
    | Puppy
    | Excluded


{-| Converte o inteiro vindo da API para `Cell`. Valores fora de `-1`, `0` e `1`
resultam em `Nothing` e são rejeitados pelo decoder JSON.
-}
cellFromInt : Int -> Maybe Cell
cellFromInt value =
    if value == 0 then
        Just Empty

    else if value == 1 then
        Just Puppy

    else if value == -1 then
        Just Excluded

    else
        Nothing


{-| Converte `Cell` de volta para o inteiro esperado pela API/Prolog.
-}
cellToInt : Cell -> Int
cellToInt cell =
    case cell of
        Empty ->
            0

        Puppy ->
            1

        Excluded ->
            -1


{-| Ciclo de uma casa ao clicar: vazia → puppy → × → vazia.
-}
nextCell : Cell -> Cell
nextCell cell =
    case cell of
        Empty ->
            Puppy

        Puppy ->
            Excluded

        Excluded ->
            Empty


{-| Lê o elemento na posição `(row, col)`, ou `Nothing` se estiver fora dos limites.
-}
at : Int -> Int -> List (List a) -> Maybe a
at row col grid =
    if row < 0 || col < 0 then
        Nothing

    else
        grid
            |> List.drop row
            |> List.head
            |> Maybe.andThen (List.drop col >> List.head)


setCell : Int -> Int -> a -> List (List a) -> List (List a)
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
count : a -> List (List a) -> Int
count value grid =
    grid
        |> List.concat
        |> List.filter ((==) value)
        |> List.length
