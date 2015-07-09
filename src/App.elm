module App where

-- Note the bottom of this page for the default imports: http://package.elm-lang.org/packages/elm-lang/core/2.1.0

-- We're just using Graphics for now because we're not doing any fancy HTML.
import Graphics.Element as Element
import Graphics.Input as Input
import Service
import Task exposing (andThen)
import Result



-- Model

{-
Only the Model type and an initial model are specified.  The current model is
stored as the current state of the foldp operation which drives the whole app forward.
-}

type alias Model =
    { currentNumber : Maybe Float
    , status : Maybe String
    , errorMessage : Maybe String
    }

initModel : Model
initModel =
    { currentNumber = Just 0
    , status = Just "Okay!"
    , errorMessage = Nothing
    }



-- Actions

{-
This follows the pattern setup in StartApp, but is more flexible with regards to
multpile action streams.  In particular, StartApp v1.0.0 assumes all actions will come from
the UI, and does not allow updates to be caused by other action signals.
-}

{-| These are the general classes of actions that can flow into our app.
The most common class is the first one of `UserAction`s and, in trivial tiny apps,
this is sometimes the *only* class!  This little app demos a Service of some sort, though,
so we want to take `ServiceAction`s into account, too.
-}

type AppAction
    = UserAction SomeUserAction
    | ServiceAction SomeServiceAction

{-| All user actions that can be triggered at this app level should be noted here.
-}

type SomeUserAction
    = RequestRandomNumber
    | RequestError
    | RequestNumberOrError

{-| These represent actions which can be caused by service responses.
Note that these do not actually detail the service responses themselves,
merely what actions can result from those respones.  The app may decide that
certain responses are ignored and not actually lead to any of these actions.
-}

type SomeServiceAction
    = WaitToReceiveNumber
    | ReceiveNumber Float
    | ReceiveError (Maybe String)

userActionsMailbox : Signal.Mailbox (Maybe SomeUserAction)
userActionsMailbox =
    Signal.mailbox Nothing

serviceActionsMailbox : Signal.Mailbox (Maybe SomeServiceAction)
serviceActionsMailbox =
    Signal.mailbox Nothing

{-| This is a signal of all the actions which may cause model updates.
Notice that `Maybe.map` is used to tag each action as either `Just <AppAction>` or `Nothing`.
In the case of the User Actions, the `AppAction` type case `UserAction <SomeUserAction>` is used,
and as might be expected `ServiceAction <SomeServiceAction>` is used for the Service Actions.
The use of `Maybe` lets us avoid filling all our Action things with `NoOp`/`NoActions`,
while `Maybe.map` takes care of either tagging things `Just (UserAction RequestRandomNumber)` etc,
or `Nothing`.  This then lets us use `foldp` later to ignore `Nothing`s instead of having to
pass `NoOp`/`NoAction` actions to `update`.
-}

appActions : Signal (Maybe AppAction)
appActions =
    Signal.mergeMany
        [ Signal.map (Maybe.map UserAction) userActionsMailbox.signal
        , Signal.map (Maybe.map ServiceAction) serviceActionsMailbox.signal
        ]



-- Update

update : AppAction -> Model -> Model
update action model =
    case action of
        UserAction userAction ->
            updateFromUserAction userAction model

        ServiceAction serviceAction ->
            updateFromServiceAction serviceAction model

updateFromUserAction : SomeUserAction -> Model -> Model
updateFromUserAction action model =
    case action of
        RequestRandomNumber ->
            { model | status <- Just "Asking for a number..." }

        RequestError ->
            { model | status <- Just "Asking for an error...!" }

        RequestNumberOrError ->
            { model | status <- Just "Asking for ... something :o" }

updateFromServiceAction : SomeServiceAction -> Model -> Model
updateFromServiceAction action model =
    case action of
        WaitToReceiveNumber ->
            { model
                | errorMessage <- Nothing
                , currentNumber <- Nothing
            }

        ReceiveNumber number ->
            { model | currentNumber <- Just number }

        ReceiveError maybeMessage ->
            let
                errorMessage =
                    Maybe.withDefault "Oh no!  A general error!" maybeMessage
            in
                { model | errorMessage <- Just errorMessage }



-- View

{-| The important thing to notice here is that view takes an `Address` only of `SomeUserAction`,
and *not* of `Maybe SomeUserAction`.  The handling of conversion to a `Maybe SomeUserAction`
will happen in the wiring up.
-}

view : Signal.Address SomeUserAction -> Model -> Element.Element
view address model = 
    --Element.show model
    Element.flow Element.down
        [ Element.show model
        , Element.flow Element.right
            [ Input.button (Signal.message address RequestRandomNumber) "Get a Random Number"
            , Input.button (Signal.message address RequestError) "Get an Error"
            , Input.button (Signal.message address RequestNumberOrError) "Get a Surprise!"
            ]
        ]



-- Wiring Up: Ports and Services

{-
The wiring up of Services is included with the Ports because without any Ports,
no Service requests will actually be processed because you'll just be left with
a pile of Tasks that don't don't actually get executed.

Currently, there's no way to specify ports outside the main file.
-}

maxNumberForRequest : Float
maxNumberForRequest = 5

serviceRequestForUserAction : SomeUserAction -> Service.Request
serviceRequestForUserAction action =
    case action of
        RequestRandomNumber ->
            Service.GetRandomNumber maxNumberForRequest

        RequestError ->
            Service.GetAnError

        RequestNumberOrError ->
            Service.GetNumberOrError maxNumberForRequest

{-
This is one way of mapping the results of service requests to actions that mutate the model.
Another way may be to just pass the Result directly into the model, and have things update based on that.
In fact, you could go further and do Maybe (Result Error Response), though in the UI that means covering all of
Nothing, Just (Ok (...)), and Just (Err (...)) and whatever sub cases may be there.
It depends on how you need to handle things.
-}
serviceActionForResult : Result.Result Service.Error Service.Response -> SomeServiceAction
serviceActionForResult result =
    case result of
        Ok (Service.RandomNumber number) ->
            ReceiveNumber number

        Err (Service.ErrorWithMessage message) ->
            ReceiveError (Just message)

        Err (Service.GenericError) ->
            ReceiveError Nothing



-- Remember that Signal.send returns a (Task.Task x ()).
port serviceRequests : Signal (Task.Task x ())
port serviceRequests =
    let
        requests =
            --Signal.map (Maybe.map serviceRequestForUserAction) serviceActionsMailbox.signal
            Signal.map (Maybe.map serviceRequestForUserAction) userActionsMailbox.signal

        taskOf maybeRequest =
            case maybeRequest of
                Just request ->
                    Signal.send serviceActionsMailbox.address (Just WaitToReceiveNumber)
                    `andThen` \_ -> Task.toResult (Service.send request)
                    `andThen` sendResult

                Nothing ->
                    -- This is the Task-ish no-op.
                    Task.succeed ()

        sendResult result =
            Signal.send serviceActionsMailbox.address (Just (serviceActionForResult result))

    in
        Signal.map taskOf requests



-- Wiring Up: App

main : Signal Element.Element
main =
    let
        -- Tag everything as `Just <thatThing>` so that we can use the `SomeUserAction`s without having to spam `Just` everywhere.
        userAddress = Signal.forwardTo userActionsMailbox.address Just

        -- Note: appActions here refers to the above defined signal, and not to any of the let values here.
        model =
            Signal.foldp
                (\(Just appAction) model -> update appAction model)
                initModel
                appActions
    in
        Signal.map (view userAddress) model
