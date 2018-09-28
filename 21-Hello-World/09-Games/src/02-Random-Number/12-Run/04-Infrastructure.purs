module Games.RandomNumber.Run.Infrastructure where

import Prelude
import Type.Row (type (+))
import Data.Functor.Variant (on)
import Run (Run, interpret, send, AFF, liftAff, runBaseAff)
import Data.Either (Either(Right))
import Effect.Random (randomInt)
import Effect.Class (liftEffect)
import Effect (Effect)
import Effect.Console (log)
import Effect.Aff (Aff, runAff_, makeAff)
import Node.ReadLine ( Interface
                     , createConsoleInterface, noCompletion
                     , close
                     )
import Node.ReadLine as NR

import Games.RandomNumber.Core (unBounds)
import Games.RandomNumber.Run.Core (game)

import Games.RandomNumber.Run.Domain (runCore)

import Games.RandomNumber.API (API_F(..))
import Games.RandomNumber.Run.API (API, _api, runDomain)

question :: String -> Interface -> Aff String
question message interface = do
  makeAff go
  where
    go handler = NR.question message (handler <<< Right) interface $> mempty

runAPI :: forall r
        . Interface
       -> Run (aff :: AFF | API + r)
       ~> Run (aff :: AFF | r)
runAPI iface_ = interpret (on _api (go iface_) send)

  where
  go :: Interface -> API_F ~> Run (aff :: AFF | r)
  go iface = case _ of
    Log msg next -> do
      liftAff $ liftEffect $ log msg

      pure next
    GetUserInput prompt reply -> do
      answer <- liftAff $ question prompt iface

      pure (reply answer)
    GenRandomInt bounds reply -> do
      random <- unBounds bounds (\l u ->
        liftAff $ liftEffect $ randomInt l u)

      pure (reply random)

main :: Effect Unit
main = do
  interface <- createConsoleInterface noCompletion

  runAff_
    (\_ -> close interface)
    (runBaseAff $ runAPI interface (runDomain (runCore game)))
