module Games.RandomNumber.Run.API (Api, API, _api, runDomain) where

import Prelude
import Data.Symbol (SProxy(..))
import Type.Row (type (+))
import Data.Functor.Variant (on)
import Run (Run, FProxy, lift, interpret, send)
import Data.Int (fromString)
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Games.RandomNumber.Core ( Bounds, mkBounds, mkGuess, mkRandomInt
                               , mkRemainingGuesses
                               )

import Games.RandomNumber.Domain (RandomNumberOperationF(..))
import Games.RandomNumber.Run.Domain (RANDOM_NUMBER_OPERATION, _domain)

import Games.RandomNumber.API (API_F(..))

type API r = (api :: FProxy API_F | r)

type Api r = Run (API + r)

_api :: SProxy "api"
_api = SProxy

getUserInput :: forall r. String -> Api r String
getUserInput prompt = lift _api (GetUserInput prompt identity)

log :: forall r. String -> Api r Unit
log msg = lift _api (Log msg unit)

genRandomInt :: forall r. Bounds -> Api r Int
genRandomInt bounds = lift _api (GenRandomInt bounds identity)

recursivelyRunUntilPure :: forall r e a. Show e => Api r (Either e a) -> Api r a
recursivelyRunUntilPure computation = do
  result <- computation
  case result of
    Left e -> do
      log $ show e <> " Please try again."
      recursivelyRunUntilPure computation
    Right a -> pure a

data InputError = NotAnInt String
instance ies :: Show InputError where
  show (NotAnInt s) = "User inputted a non-integer value: " <> s

inputIsInt :: String -> Either InputError Int
inputIsInt s = case fromString s of
  Just i -> Right i
  Nothing -> Left $ NotAnInt s

runDomain :: forall r
           . Run (RANDOM_NUMBER_OPERATION + API + r)
          ~> Api r
runDomain = interpret (on _domain go send)

  where
  getIntFromUser :: String -> Api r Int
  getIntFromUser prompt =
    recursivelyRunUntilPure (inputIsInt <$> getUserInput prompt)

  go :: RandomNumberOperationF ~> Api r
  go = case _ of
    NotifyUser msg next -> do
      log msg
      pure next

    DefineBounds reply -> do
      bounds <- recursivelyRunUntilPure
        (mkBounds
          <$> getIntFromUser "Please enter either the lower or upper bound: "
          <*> getIntFromUser "Please enter the other bound: ")
      pure (reply bounds)

    DefineTotalGuesses reply -> do
      totalGuesses <- recursivelyRunUntilPure
        (mkRemainingGuesses <$>
          getIntFromUser "Please enter the total number of guesses: ")
      pure (reply totalGuesses)

    GenerateRandomInt bounds reply -> do
      random <- recursivelyRunUntilPure
        (mkRandomInt bounds <$> genRandomInt bounds)
      pure (reply random)

    MakeGuess bounds reply -> do
      guess <- recursivelyRunUntilPure
        ((mkGuess bounds) <$> getIntFromUser "Your guess: ")
      pure (reply guess)
