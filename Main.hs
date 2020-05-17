{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
module Main where


import Data.Conduit        ( runConduit, (.|) )
import Data.Conduit.Binary ( sourceHandleRangeWithBuffer )
import Data.Text           ( pack )
import Data.Functor        ( (<&>) )
import Control.Lens        ( set )
import Network.AWS
import Network.AWS.Data.Text                ( fromText )
import Network.AWS.S3.CreateMultipartUpload
import Network.AWS.S3.StreamingUpload

import Control.Monad.IO.Class ( liftIO )
import System.Environment
import System.IO              ( BufferMode(BlockBuffering), hSetBuffering, stdin )

#if !MIN_VERSION_base(4,8,0)
import Control.Applicative ( pure, (<$>), (<*>) )
#endif

main :: IO ()
main = do
  args <- getArgs
  case args of
    (region:profile:credfile:bucket:key:file:_) ->
      case (,,,) <$> (FromFile <$> fromText (pack profile) <*> pure credfile)
                 <*> (fromText (pack region) :: Either String Region)
                 <*> fromText (pack bucket)
                 <*> fromText (pack key)
      of
        Right (creds,reg,buck,ky) -> do
          env <- newEnv creds <&> set envRegion reg
          hSetBuffering stdin (BlockBuffering Nothing)
          res <- runResourceT . runAWS env $ case file of
                  "-" -> runConduit (sourceHandleRangeWithBuffer stdin Nothing Nothing (6 * 1024 * 1024)  .| streamUpload Nothing (createMultipartUpload buck ky))
                          >>= liftIO . either print print
                  _   -> concurrentUpload Nothing Nothing (FP file) (createMultipartUpload buck ky)
                          >>= liftIO . print

          print res
        Left err -> print err >> usage
    ("abort":region:profile:credfile:bucket:_) ->
      case (,,) <$> (FromFile <$> fromText (pack profile) <*> pure credfile)
                <*> (fromText (pack region) :: Either String Region)
                <*> fromText (pack bucket)
      of
        Right (creds,reg,buck) -> do
          env <- newEnv creds <&> set envRegion reg
          res <- runResourceT . runAWS env . abortAllUploads $ buck
          print res
        Left err -> print err >> usage

    _ -> usage

usage :: IO ()
usage = putStrLn . unlines $
  [ "Usage: \n"
  , "  Upload file:"
  , "    s3upload <region:ap-southeast-2> <profile> <credentials file:$HOME/.aws/credentials> <bucket> <object key> <file to upload>"
  , "  Abort all unfinished uploads for bucket:"
  , "    s3upload abort <region:ap-southeast-2> <profile> <credentials file:$HOME/.aws/credentials> <bucket>\n"
  , "all arguments must be supplied - the region will be obtained from the AWS_REGION env var"
  , "if compiled with amazonka > 1.4.4, but must still be supplied (making an option parsing library"
  , "a dependency of this package seemed overkill)"
 ]
