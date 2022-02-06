module Main exposing (..)

import Browser
import Csv.Encode exposing (Csv)
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Json.Decode exposing (Decoder, field, int, maybe, string)
import List exposing (length)
import Maybe exposing (withDefault)
import File.Download as Download




-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- MODEL


type alias Address =
    String


type alias Reward =
    { timestamp : Timestamp, amount : Int, block : Int }


type alias Model =
    { address : Address
    , hotspot : Maybe Hotspot
    , rewards : List Reward
    , debug : String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { address = "112ChG5vb21nE2wn4x4DYzDnG1VDCaRTbxrRXeBLkg2VFgEuWYfV", hotspot = Nothing, rewards = [], debug = "" }, Cmd.none )



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
            ( { model | hotspot = Just hotspot }, getRewards model.address Nothing )

        GotHotspot (Err err) ->
            ( model, Cmd.none )

        GotRewards (Ok rewardsResponse) ->
            case rewardsResponse.cursor of
                Just cursor ->
                    ( { model | debug = "cursor", rewards = model.rewards ++ rewardsResponse.data }, getRewards model.address (Just cursor) )

                Nothing ->
                    ( { model | debug = "none", rewards = model.rewards ++ rewardsResponse.data }, Cmd.none )

        GotRewards (Err err) ->
            ( { model | debug = Debug.toString err }, downloadCsv model.rewards )


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
            { headers = [ "timestamp", "amount", "block" ], records = (List.map rewardToRow rewards) }
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
        , div [] [ text ("TEST " ++ model.debug) ]
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
        { url = "https://api.helium.io/v1/hotspots/" ++ address ++ "/rewards?min_time=2020-01-01T07:00:00.000Z" ++ cursorParam cursor
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
    Json.Decode.map2 RewardsResponse (field "data" (Json.Decode.list rewardDecoder)) (field "cursor" (maybe string))
