port module Main exposing (..)

import Browser
import Csv.Encode exposing (Csv)
import Debug exposing (toString)
import File.Download as Download
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Json.Decode exposing (Decoder, field, int, maybe, string)
import List exposing (length)
import Maybe exposing (withDefault)



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


port sendError : String -> Cmd msg



-- MODEL


type alias Address =
    String


type alias Reward =
    { timestamp : Timestamp, amount : Int, block : Int }


type alias Model =
    { address : Address
    , hotspot : Maybe Hotspot
    , rewards : List Reward
    , log : List String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { address = "112ChG5vb21nE2wn4x4DYzDnG1VDCaRTbxrRXeBLkg2VFgEuWYfV", hotspot = Nothing, rewards = [], log = [] }, Cmd.none )



-- UPDATE


type alias Hotspot =
    { name : String }


type Msg
    = Change String
    | Submit
    | GotHotspot (Result Http.Error Hotspot)
    | GotRewards (Result Http.Error RewardsResponse)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Change newContent ->
            ( { model | address = newContent }, Cmd.none )

        Submit ->
            ( model, getHotspot model.address )

        GotHotspot (Ok hotspot) ->
            ( { model | hotspot = Just hotspot, log = ("Found " ++ hotspot.name) :: model.log }, getRewards model.address Nothing )

        GotHotspot (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )

        GotRewards (Ok rewardsResponse) ->
            case rewardsResponse.cursor of
                Just cursor ->
                    ( { model | rewards = model.rewards ++ rewardsResponse.data }, getRewards model.address (Just cursor) )

                Nothing ->
                    ( { model | rewards = model.rewards ++ rewardsResponse.data, log = "Starting download" :: model.log }, downloadCsv model.rewards )

        GotRewards (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )


rewardToRow : Reward -> List String
rewardToRow reward =
    [ reward.timestamp
    , String.fromInt reward.amount
    , String.fromInt reward.block
    ]


downloadCsv : List Reward -> Cmd Msg
downloadCsv rewards =
    let
        csv =
            { headers = [ "timestamp", "amount", "block" ], records = List.map rewardToRow rewards }
    in
    Download.string "rewards.md" "text/csv" (Csv.Encode.toString csv)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


name : Maybe Hotspot -> String
name hotspot =
    case hotspot of
        Just h ->
            h.name

        Nothing ->
            ""


view : Model -> Html Msg
view model =
    div []
        [ input [ placeholder "Text to reverse", value model.address, onInput Change ] []
        , button [ onClick Submit ] [ text "Submit" ]
        , div [] [ text (name model.hotspot) ]
        , div [] [ text (String.fromInt (length model.rewards)) ]
        , div [] [ ul [] (List.map (\x -> li [] [ text x ]) (List.reverse model.log)) ]
        ]



-- HTTP


getHotspot : Address -> Cmd Msg
getHotspot address =
    Http.get
        { url = "https://api.helium.io/v1/hotspots/" ++ address
        , expect = Http.expectJson GotHotspot hotspotDecoder
        }


hotspotDecoder : Decoder Hotspot
hotspotDecoder =
    Json.Decode.map Hotspot (field "data" (field "name" string))


type alias Cursor =
    String


cursorParam : Maybe Cursor -> String
cursorParam c =
    case c of
        Nothing ->
            ""

        Just cursor ->
            "&cursor=" ++ cursor


getRewards : Address -> Maybe Cursor -> Cmd Msg
getRewards address cursor =
    Http.get
        { url = "https://api.helium.io/v1/hotspots/" ++ address ++ "/rewards?min_time=2022-01-22T07:00:00.000Z" ++ cursorParam cursor
        , expect = Http.expectJson GotRewards rewardsDecoder
        }


type alias Timestamp =
    String


rewardDecoder : Decoder Reward
rewardDecoder =
    Json.Decode.map3 Reward (field "timestamp" string) (field "amount" int) (field "block" int)


type alias RewardsResponse =
    { data : List Reward, cursor : Maybe String }


rewardsDecoder : Decoder RewardsResponse
rewardsDecoder =
    Json.Decode.map2 RewardsResponse (field "data" (Json.Decode.list rewardDecoder)) (maybe (field "cursor" string))



-- https://stackoverflow.com/questions/56442885/error-when-convert-http-error-to-string-with-tostring-in-elm-0-19


errorToString : Http.Error -> String
errorToString error =
    case error of
        BadUrl url ->
            "The URL " ++ url ++ " was invalid"

        Timeout ->
            "Unable to reach the server, try again"

        NetworkError ->
            "Unable to reach the server, check your network connection"

        BadStatus code ->
            "Error " ++ String.fromInt code

        BadBody errorMessage ->
            errorMessage
