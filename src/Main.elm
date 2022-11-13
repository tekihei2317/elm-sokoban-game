module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Events exposing (onKeyDown)
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events
import Json.Decode as Decode


main : Program () Model Msg
main =
    Browser.element
        { init = initialModel
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ onKeyDown (Decode.map Keypress keyDecoder)
        ]


type alias Position =
    { x : Int
    , y : Int
    }


type alias Model =
    { stage : Array (Array Cell)
    , line : Array Int
    , playerPosition : Position
    }


initialModel : () -> ( Model, Cmd msg )
initialModel _ =
    ( { stage = initialStage |> convertStringStage
      , line = Array.initialize 5 identity
      , playerPosition = { y = 1, x = 1 }
      }
    , Cmd.none
    )


initialStage : List String
initialStage =
    [ "#####"
    , "#@  #"
    , "# $ #"
    , "### #"
    , "#.$ #"
    , "#  .#"
    , "#####"
    ]


convertStringStage : List String -> Array (Array Cell)
convertStringStage stage =
    stage |> Array.fromList |> Array.map (\line -> line |> String.split "" |> List.map stringToCell |> Array.fromList)


type Direction
    = Left
    | Right
    | Up
    | Down
    | Other


toDirection : String -> Direction
toDirection string =
    case string of
        "ArrowLeft" ->
            Left

        "ArrowRight" ->
            Right

        "ArrowUp" ->
            Up

        "ArrowDown" ->
            Down

        _ ->
            Other


keyDecoder =
    Decode.map toDirection (Decode.field "key" Decode.string)


type Msg
    = Keypress Direction
    | Increment


updatePosition : Direction -> Position -> Position
updatePosition direction position =
    case direction of
        Up ->
            { position | y = position.y - 1 }

        Down ->
            { position | y = position.y + 1 }

        Right ->
            { position | x = position.x + 1 }

        Left ->
            { position | x = position.x - 1 }

        _ ->
            position


type alias Neighborhood =
    { current : Maybe Cell
    , next : Maybe Cell
    , afterNext : Maybe Cell
    }


wrapCellsWithJust : Cell -> Cell -> Cell -> Neighborhood
wrapCellsWithJust cell nextCell afterNextCell =
    { current = Just cell
    , next = Just nextCell
    , afterNext = Just afterNextCell
    }


updateJustNeighborhood : Cell -> Cell -> Cell -> ( Neighborhood, Bool )
updateJustNeighborhood cell nextCell afterNextCell =
    let
        noChange =
            wrapCellsWithJust cell nextCell afterNextCell
    in
    case cell of
        Player onObjective ->
            case nextCell of
                Empty ->
                    ( wrapCellsWithJust
                        (if onObjective then
                            Objective

                         else
                            Empty
                        )
                        (Player False)
                        afterNextCell
                    , True
                    )

                Objective ->
                    ( wrapCellsWithJust
                        (if onObjective then
                            Objective

                         else
                            Empty
                        )
                        (Player True)
                        afterNextCell
                    , True
                    )

                _ ->
                    ( noChange, False )

        _ ->
            ( noChange, False )


updateNeighborhood : Neighborhood -> ( Neighborhood, Bool )
updateNeighborhood cells =
    -- Maybeがつらいだろうなぁ
    case cells.current of
        Nothing ->
            ( cells, False )

        Just cell ->
            case cells.next of
                Nothing ->
                    ( cells, False )

                Just nextCell ->
                    case cells.afterNext of
                        Nothing ->
                            ( cells, False )

                        Just afterNextCell ->
                            updateJustNeighborhood cell nextCell afterNextCell


getNextPosition : Direction -> Position -> Position
getNextPosition direction position =
    case direction of
        Up ->
            { position | y = position.y - 1 }

        Down ->
            { position | y = position.y + 1 }

        Right ->
            { position | x = position.x + 1 }

        Left ->
            { position | x = position.x - 1 }

        _ ->
            position


getNeighborhood : Array (Array Cell) -> Direction -> Position -> Neighborhood
getNeighborhood stage direction position =
    let
        nextPosition =
            position |> getNextPosition direction

        afterNextPosition =
            nextPosition |> getNextPosition direction
    in
    { current = stage |> Array.get position.y |> Maybe.andThen (Array.get position.x)
    , next = stage |> Array.get nextPosition.y |> Maybe.andThen (Array.get nextPosition.x)
    , afterNext = stage |> Array.get afterNextPosition.y |> Maybe.andThen (Array.get afterNextPosition.x)
    }


type alias Stage =
    Array (Array Cell)


updateCell : Position -> Maybe Cell -> Stage -> Stage
updateCell position maybeCell stage =
    let
        maybeRow =
            stage |> Array.get position.y
    in
    -- つらい
    case maybeCell of
        Nothing ->
            stage

        Just cell ->
            case maybeRow of
                Nothing ->
                    stage

                Just row ->
                    stage |> Array.set position.y (row |> Array.set position.x cell)


updateStage : Stage -> Direction -> Position -> ( Stage, Bool )
updateStage stage direction playerPosition =
    let
        ( updatedNeighborhood, playerMoved ) =
            getNeighborhood stage direction playerPosition |> updateNeighborhood

        nextPosition =
            playerPosition |> getNextPosition direction

        afterNextPosition =
            nextPosition |> getNextPosition direction
    in
    ( stage
        |> updateCell playerPosition updatedNeighborhood.current
        |> updateCell nextPosition updatedNeighborhood.next
        |> updateCell afterNextPosition updatedNeighborhood.afterNext
    , playerMoved
    )


incrementLine : Array Int -> Array Int
incrementLine line =
    line |> Array.set 0 3 |> Array.set 1 1 |> Array.set 2 4 |> Array.set 3 1 |> Array.set 4 5


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        Keypress direction ->
            let
                ( updatedStage, playerMoved ) =
                    updateStage model.stage direction model.playerPosition

                playerPosition =
                    if playerMoved then
                        updatePosition direction model.playerPosition

                    else
                        model.playerPosition
            in
            ( { model
                | stage = updatedStage
                , playerPosition = playerPosition
              }
            , Cmd.none
            )

        Increment ->
            ( { model | line = incrementLine model.line }, Cmd.none )


type alias OnObjective =
    Bool


type Cell
    = Empty
    | Objective
    | Wall
    | Player OnObjective
    | Box OnObjective


stringToCell : String -> Cell
stringToCell str =
    if str == "@" then
        Player False

    else if str == "#" then
        Wall

    else if str == "$" then
        Box False

    else if str == "." then
        Objective

    else
        Empty


getCellClass : Cell -> String
getCellClass cell =
    case cell of
        -- プレイヤーは位置をもとにクラスをつける
        Player _ ->
            "player"

        Wall ->
            "wall"

        Box _ ->
            "box"

        Objective ->
            "objective"

        Empty ->
            "empty"


cn : List String -> String
cn classNames =
    String.join " " classNames


stageCell : Int -> Int -> Cell -> Html msg
stageCell rowNumber colNumber cell =
    let
        cellClass =
            getCellClass cell
    in
    div [ class (cn [ "cell", cellClass ]) ] []


stageLine : Int -> Array Cell -> Html msg
stageLine rowNumber line =
    div [ class "board-row" ] (line |> Array.toList |> List.indexedMap (stageCell rowNumber))


view : Model -> Html Msg
view model =
    div []
        [ div [] (model.stage |> Array.toList |> List.indexedMap stageLine)
        , div [] (model.line |> Array.toList |> List.map (\number -> span [] [ text (String.fromInt number) ]))
        , button [ Html.Events.onClick Increment ] [ text "Increment" ]
        ]
