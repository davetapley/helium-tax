port module Main exposing (..)

import Http exposing (..)
import Browser
import Csv.Encode
import File.Download as Download
import Helium exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import List exposing (length)

import Helium
import Time exposing (Month(..))


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

type alias Model =
    { helium : Maybe Helium.Model
    , address : String
    }

type Selectable
    = SelectAccount Address
    | SelectHotspot Hotspot


init : () -> ( Model, Cmd Msg )
init _ =
    ( { address = "13ZZFMfMKQCmHxGAkQChPDXb39R4tsqCm8TogY85KV4Ndi34F7Z", helium = Nothing }, Cmd.none )


-- UPDATE


type Msg
    = Change String
    | Submit
    | CheckBox Selectable
    | HeliumMsg Helium.Msg

rewardToRow : Helium.Reward -> List String
rewardToRow reward =
    [ reward.timestamp
    , String.fromInt reward.block
    , String.fromInt reward.amount
    ]

downloadCsv : List Reward -> Cmd Msg
downloadCsv rewards =
    let
        csv =
           { headers = [ "timestamp", "block", "amount" ], records = List.map rewardToRow rewards }
    in
   Download.string "rewards.csv" "text/csv" (Csv.Encode.toString csv)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Change newContent ->
            ( { model | address = newContent }, Cmd.none )

        Submit ->
            let hModel = Helium.init model.address
            in ( {model | helium = Just hModel }, Cmd.map HeliumMsg (getAccount model.address) )

        CheckBox selectable ->
            case selectable of
                SelectAccount address ->
                    ( model, Cmd.map HeliumMsg (getPaymentActivity address minTime Nothing) )

                SelectHotspot hotspot ->
                    ( model, Cmd.map HeliumMsg (getRewards hotspot.address minTime Nothing) )

        HeliumMsg m -> 
            case model.helium of
               Nothing ->
                (model, Cmd.none)
               Just helium ->
                 let (model_, cmd_) = Helium.update m helium
                 in ( { model | helium = Just model_ }, Cmd.map HeliumMsg cmd_ )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ input [ placeholder "Address", value model.address, onInput Change ] []
        , button [ onClick Submit ] [ text "Submit" ]
        , viewAccount model.helium
        ]

viewAccount : Maybe Helium.Model -> Html Msg
viewAccount mModel =
    case mModel of
        Nothing -> div [] []
        Just model -> div []
            [ div [] [ viewEligible model.account model.hotspots ]
            , div [] [ text ("rewards " ++ String.fromInt (length model.rewards)) ]
            , div [] [ ul [] (List.map (\x -> li [] [ text x ]) (List.reverse model.log)) ]
            ]


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




