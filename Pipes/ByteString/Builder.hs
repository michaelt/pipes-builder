{-#LANGUAGE OverloadedStrings #-}
module Pipes.ByteString.Builder (fromBuilders) where
  
import Control.Monad (unless, liftM)
import Control.Monad.Trans

import qualified Data.ByteString as B
import Data.ByteString (ByteString)
import Data.ByteString.Builder
import Data.Streaming.ByteString.Builder.Class

import Pipes 
import Pipes.Internal 


-- modeled somewhat on 'helper' in 
-- Data.Conduit.ByteString.Builder

fromBuilders
  :: (MonadIO m, StreamingBuilder builder) =>
     BufferAllocStrategy
     -> Producer builder m b -> Producer ByteString m b
fromBuilders strat p0 = do
  (recv, finish) <- liftIO $ newBuilderRecv strat
  let loop p = case p of  -- this could just use `next`
        Pure r -> do
          mbs <- liftIO finish
          case mbs of
               Nothing -> return r
               Just bs -> yield bs >> return r
        Respond builder f -> do
          popper <- liftIO $ recv builder
          let cont' = do
                  bs <- liftIO popper
                  unless (B.null bs) $ yield bs >> cont'
          cont'
          loop (f ())
        Request x _ -> closed x
        M mp -> M (liftM loop mp)
  loop p0
