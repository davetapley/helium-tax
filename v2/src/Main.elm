port module Main exposing (..)

import Browser
import Csv.Encode
import File.Download as Download
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (..)
import Iso8601
import Json.Decode exposing (Decoder, andThen, field, int, maybe, string, succeed)
import List exposing (concatMap, length)
import Maybe.Extra exposing (isJust)
import Time



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


type alias Hotspot =
    { name : String, address : Address }


type alias PaymentActivity =
    { time : Time, payments : List Int }


type alias Reward =
    { timestamp : Timestamp, amount : Int }


paymentActivityToReward : PaymentActivity -> List Reward
paymentActivityToReward paymentActivity =
    let
        toISO =
            (*) 1000 >> Time.millisToPosix >> Iso8601.fromTime

        toReward p =
            { timestamp = toISO paymentActivity.time, amount = p }
    in
    List.map toReward paymentActivity.payments


type alias Model =
    { address : Address
    , account : Maybe Address
    , hotspots : List Hotspot
    , rewards : List Reward
    , log : List String
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { address = "14dgxU7ZzgrCjXcEjKYuKNXePRqMFYVwitbgHspUNMyd3HsbJDD", account = Nothing, hotspots = [], rewards = [], log = [] }, Cmd.none )



-- UPDATE


type Msg
    = Change String
    | Submit
    | GotAccount (Result Http.Error Bool)
    | GotPaymentActivity (Result Http.Error PaymentActivityResponse)
    | GotHotspot (Result Http.Error Hotspot)
    | GotRewards (Result Http.Error RewardsResponse)
    | CheckBox Selectable


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Change newContent ->
            ( { model | address = newContent }, Cmd.none )

        Submit ->
            ( model, getHotspot model.address )

        GotAccount (Ok isAccount) ->
            ( { model
                | account =
                    if isAccount then
                        Just model.address

                    else
                        Nothing
                , log =
                    if isAccount then
                        "Found account" :: model.log

                    else
                        model.log
              }
            , if isAccount then
                Cmd.none

              else
                getHotspot model.address
            )

        GotAccount (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )

        GotHotspot (Ok hotspot) ->
            ( { model | hotspots = [ hotspot ], log = ("Found " ++ hotspot.name) :: model.log }, getRewards model.address Nothing )

        GotHotspot (Err err) ->
            case err of
                BadStatus 404 ->
                    ( model, getAccount model.address )

                _ ->
                    ( { model | log = errorToString err :: model.log }, Cmd.none )

        GotPaymentActivity (Ok paymentActivityResponse) ->
            case paymentActivityResponse.cursor of
                Just cursor ->
                    ( { model | rewards = model.rewards ++ List.concatMap paymentActivityToReward paymentActivityResponse.data }, getPaymentActivity model.address (Just cursor) )

                Nothing ->
                    ( { model | rewards = model.rewards ++ List.concatMap paymentActivityToReward paymentActivityResponse.data, log = "Starting download" :: model.log }, downloadCsv model.rewards )

        GotPaymentActivity (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )

        GotRewards (Ok rewardsResponse) ->
            case rewardsResponse.cursor of
                Just cursor ->
                    ( { model | rewards = model.rewards ++ rewardsResponse.data }, getRewards model.address (Just cursor) )

                Nothing ->
                    ( { model | rewards = model.rewards ++ rewardsResponse.data, log = "Starting download" :: model.log }, downloadCsv model.rewards )

        GotRewards (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )

        CheckBox selectable ->
            case selectable of
                SelectAccount address ->
                    ( model, getPaymentActivity address Nothing )

                SelectHotspot hotspot ->
                    ( model, getRewards hotspot.address Nothing )


rewardToRow : Reward -> List String
rewardToRow reward =
    [ reward.timestamp
    , String.fromInt reward.amount
    ]


downloadCsv : List Reward -> Cmd Msg
downloadCsv rewards =
    let
        csv =
            { headers = [ "timestamp", "amount" ], records = List.map rewardToRow rewards }
    in
    Download.string "rewards.csv" "text/csv" (Csv.Encode.toString csv)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ input [ placeholder "Text to reverse", value model.address, onInput Change ] []
        , button [ onClick Submit ] [ text "Submit" ]
        , div [] [ viewEligible model.account model.hotspots ]
        , div [] [ text (String.fromInt (length model.rewards)) ]
        , div [] [ ul [] (List.map (\x -> li [] [ text x ]) (List.reverse model.log)) ]
        ]


type Selectable
    = SelectAccount Address
    | SelectHotspot Hotspot


viewEligible : Maybe Address -> List Hotspot -> Html Msg
viewEligible account hotspots =
    let
        selectAccount =
            case account of
                Just address ->
                    [ checkbox (SelectAccount address) address ]

                Nothing ->
                    []

        selectHotspots =
            List.map (\h -> checkbox (SelectHotspot h) h.name) hotspots
    in
    fieldset [] (selectAccount ++ selectHotspots)


checkbox : Selectable -> String -> Html Msg
checkbox selectable name =
    label
        [ style "padding" "20px" ]
        [ input [ type_ "checkbox", onClick (CheckBox selectable) ] []
        , text name
        ]



-- HTTP


getAccount : Address -> Cmd Msg
getAccount address =
    Http.get
        { url = "https://api.helium.io/v1/accounts/" ++ address
        , expect = Http.expectJson GotAccount accountDecoder
        }


accountDecoder : Decoder Bool
accountDecoder =
    field "data" (field "block" (maybe int)) |> andThen (isJust >> succeed)


getHotspot : Address -> Cmd Msg
getHotspot address =
    Http.get
        { url = "https://api.helium.io/v1/hotspots/" ++ address
        , expect = Http.expectJson GotHotspot hotspotDecoder
        }


hotspotDecoder : Decoder Hotspot
hotspotDecoder =
    Json.Decode.map2 Hotspot (field "data" (field "name" string)) (field "data" (field "address" string))


type alias Cursor =
    String


cursorParam : Maybe Cursor -> String
cursorParam c =
    case c of
        Nothing ->
            ""

        Just cursor ->
            "&cursor=" ++ cursor


minTime =
    "2022-01-01T07:00:00.000Z"


type alias Time =
    Int


getPaymentActivity : Address -> Maybe Cursor -> Cmd Msg
getPaymentActivity address cursor =
    Http.get
        { url = "https://api.helium.io/v1/accounts/" ++ address ++ "/activity?filter_types=payment_v2&min_time=" ++ minTime ++ cursorParam cursor
        , expect = Http.expectJson GotPaymentActivity paymentActivityDecoder
        }


paymentActivityDecoder : Decoder PaymentActivityResponse
paymentActivityDecoder =
    let
        a =
            Json.Decode.map2 PaymentActivity (field "time" int) (field "payments" (Json.Decode.list (field "amount" int)))
    in
    Json.Decode.map2 PaymentActivityResponse (field "data" (Json.Decode.list a)) (maybe (field "cursor" string))


type alias PaymentActivityResponse =
    { data : List PaymentActivity, cursor : Maybe String }


getRewards : Address -> Maybe Cursor -> Cmd Msg
getRewards address cursor =
    Http.get
        { url = "https://api.helium.io/v1/hotspots/" ++ address ++ "/rewards?min_time=" ++ minTime ++ cursorParam cursor
        , expect = Http.expectJson GotRewards rewardsDecoder
        }


type alias Timestamp =
    String


rewardDecoder : Decoder Reward
rewardDecoder =
    Json.Decode.map2 Reward (field "timestamp" string) (field "amount" int)


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
