module Service where

import Task exposing (Task)
import Native.Service

{-
This is a simple service which returns a random number when you ask for a random number,
or an error when you ask for an error.

But, there's a trick!
It waits 3 seconds before actually returning this number or error!
-}

type Request
    -- Get a random number between 0 and the provided number.
    = GetRandomNumber Float
    -- This causes the request to fail.
    | GetAnError
    -- This randomly returns either a number (with the limit specified as above) or an error.
    | GetNumberOrError Float

type Error
    = ErrorWithMessage String
    | GenericError

type Response
    = RandomNumber Float

send : Request -> Task Error Response
send =
    Native.Service.send
