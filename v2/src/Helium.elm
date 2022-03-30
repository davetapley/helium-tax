module Helium exposing (..)
import Iso8601
import Time

import Http
import Json.Decode exposing (Decoder, andThen, field, int, maybe, string, succeed)
import Http exposing (..)
import Maybe.Extra exposing (isJust)
import List
import List.Extra
import Maybe exposing (withDefault)

type alias Model =
    { address : Address
    , account : Maybe Address
    , hotspots : List Hotspot
    , rewards : List Reward
    , gotRewards : Bool
    , prices : List Price
    , gotPrices : Bool
    , log : List String
    }


type alias Address =
    String


type alias Hotspot =
    { name : String, address : Address }


type alias PaymentActivityV2 =
    { height : Int, time : Time, payments : List Int }


type alias Reward =
    { block : Int, timestamp : Timestamp, amount : Int }

type alias Price =
    { block : Int, timestamp : Timestamp, price : Int }

init : Address -> Model
init address =
    { address = address, account = Nothing, hotspots = [], rewards = [], gotRewards = False, prices = [], gotPrices = False, log = [] }

type Msg
    = GotAccount (Result Http.Error Bool)
    | GotPaymentActivity (Result Http.Error PaymentActivityResponse)
    | GotHotspot (Result Http.Error Hotspot)
    | GotRewards (Result Http.Error RewardsResponse)
    | GotPrices (Result Http.Error PricesResponse)


baseURL = "https://ugxlyxnlrg9udfdyzwnrvghlu2vydmvycg.blockjoy.com"

bone = 100000000

getAccount : Address -> Cmd Msg
getAccount address =
    Http.get
        { url = baseURL ++ "/v1/accounts/" ++ address
        , expect = Http.expectJson GotAccount accountDecoder
        }


accountDecoder : Decoder Bool
accountDecoder =
    field "data" (field "block" (maybe int)) |> andThen (isJust >> succeed)


getHotspot : Address -> Cmd Msg
getHotspot address =
    Http.get
        { url = baseURL ++ "/v1/hotspots/" ++ address
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


type alias Time =
    Int


getPaymentActivity : Address -> String -> Maybe Cursor -> Cmd Msg
getPaymentActivity address time cursor =
    Http.get
        { url = baseURL ++ "/v1/accounts/" ++ address ++ "/activity?filter_types=payment_v2&min_time=" ++ time ++ cursorParam cursor
        , expect = Http.expectJson GotPaymentActivity paymentActivityDecoder
        }


paymentActivityDecoder : Decoder PaymentActivityResponse
paymentActivityDecoder =
    let
        a =
            Json.Decode.map3 PaymentActivityV2 (field "height" int) (field "time" int) (field "payments" (Json.Decode.list (field "amount" int)))
    in
    Json.Decode.map2 PaymentActivityResponse (field "data" (Json.Decode.list a)) (maybe (field "cursor" string))


type alias PaymentActivityResponse =
    { data : List PaymentActivityV2, cursor : Maybe String }


getRewards : Address -> String -> Maybe Cursor -> Cmd Msg
getRewards address time cursor =
    Http.get
        { url = baseURL ++ "/v1/hotspots/" ++ address ++ "/rewards?min_time=" ++ time ++ cursorParam cursor
        , expect = Http.expectJson GotRewards rewardsDecoder
        }


type alias Timestamp =
    String


type alias RewardsResponse =
    { data : List Reward, cursor : Maybe String }

type alias PricesResponse =
    { data : List Price, cursor : Maybe String }

rewardsDecoder : Decoder RewardsResponse
rewardsDecoder =
    let
        a =
            Json.Decode.map3 Reward (succeed 0) (field "timestamp" string) (field "amount" int) -- TODO get real block height
    in
    Json.Decode.map2 RewardsResponse (field "data" (Json.Decode.list a)) (maybe (field "cursor" string))


paymentActivityToReward : PaymentActivityV2 -> List Reward
paymentActivityToReward paymentActivity =
    let
        toISO =
            (*) 1000 >> Time.millisToPosix >> Iso8601.fromTime

        toReward p =
            { block = paymentActivity.height, timestamp = toISO paymentActivity.time, amount = p }
    in
    List.map toReward paymentActivity.payments


getPrices : Maybe Cursor -> Cmd Msg
getPrices cursor =
    Http.get
        { url = baseURL ++ "/v1/oracle/prices?" ++ cursorParam cursor
        , expect = Http.expectJson GotPrices pricesDecoder
        }

pricesDecoder : Decoder PricesResponse
pricesDecoder =
    let
        price =
            Json.Decode.map3 Price (field "block" int) (field "timestamp" string) (field "price" int)
    in
    Json.Decode.map2 PricesResponse (field "data" (Json.Decode.list price)) (maybe (field "cursor" string))



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

minTime =
    "2021-01-01T07:00:00.000Z"
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
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
                (getHotspot model.address)
            )

        GotAccount (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )

        GotHotspot (Ok hotspot) ->
            ( { model | hotspots = [ hotspot ], log = ("Found " ++ hotspot.name) :: model.log }, (getRewards model.address minTime Nothing) )

        GotHotspot (Err err) ->
            case err of
                BadStatus 404 ->
                    ( model, (getAccount model.address) )

                _ ->
                    ( { model | log = errorToString err :: model.log }, Cmd.none )
        GotPaymentActivity (Ok paymentActivityResponse) ->
                let newRewards = List.concatMap paymentActivityToReward paymentActivityResponse.data
                in case paymentActivityResponse.cursor of
                    Just cursor ->
                        ( { model | rewards = model.rewards ++ newRewards },  (getPaymentActivity model.address minTime (Just cursor)) )

                    Nothing ->
                        ( { model | rewards = model.rewards ++ newRewards, log = "Got rewards" :: model.log, gotRewards = True }, Cmd.none )

        GotPaymentActivity (Err err) ->
            let errStr = errorToString err
            in Debug.log errStr ( { model | log =  errStr :: model.log }, Cmd.none )

        GotRewards (Ok rewardsResponse) ->
            case rewardsResponse.cursor of
                Just cursor ->
                    ( { model | rewards = model.rewards ++ rewardsResponse.data }, (getRewards model.address minTime (Just cursor)) )

                Nothing ->
                    ( { model | rewards = model.rewards ++ rewardsResponse.data, log = "Got rewards" :: model.log, gotRewards = True }, Cmd.none )

        GotRewards (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )

        GotPrices (Ok pricesResponse) ->
            case pricesResponse.cursor of
                Just cursor ->
                    ( { model | prices = model.prices ++ pricesResponse.data }, (getPrices (Just cursor)) )

                Nothing ->
                    ( { model | prices = model.prices ++ pricesResponse.data, log = "Got prices" :: model.log, gotPrices = True }, Cmd.none )

        GotPrices (Err err) ->
            ( { model | log = errorToString err :: model.log }, Cmd.none )


zipPrices : List Price -> List Reward -> List (Reward, Int)
zipPrices prices rewards =
    let findPrice block = (List.Extra.find (\p -> block > p.block)) prices
    in List.map (\r -> (r,  (findPrice r.block |> Maybe.map .price |> Maybe.withDefault 0))) rewards