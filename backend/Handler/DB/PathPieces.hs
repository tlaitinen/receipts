{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE UndecidableInstances #-}

module Handler.DB.PathPieces where
import qualified Web.PathPieces as PP
import Database.Persist.Types
import Database.Persist.Sql
import Prelude
import Data.Time (TimeOfDay, UTCTime, ZonedTime)
import Data.Int (Int64, Int32)
import Data.Word (Word32,Word64)
import Data.Maybe
import qualified Data.Text as T
import qualified Data.Text.Lazy as L
import qualified Data.Text.Read
import Data.Time (Day)
import Control.Exception (assert)

safeRead :: forall a. Read a => T.Text -> Maybe a
safeRead s = case (reads $ T.unpack s) of
   [(v,_)] -> Just v
   _ -> Nothing

class PathPiece s where
    fromPathPiece :: T.Text -> Maybe s
    toPathPiece :: s -> T.Text

instance PathPiece String where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece T.Text where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece L.Text where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece Integer where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece Int where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece Bool where
    fromPathPiece "true" = Just True
    fromPathPiece "false" = Just False
    fromPathPiece "True" = Just True
    fromPathPiece "False" = Just False
    fromPathPiece  _ = Nothing
    toPathPiece = T.pack . show

instance PathPiece Double where
    fromPathPiece s = 
        case Data.Text.Read.double s of
            Right (i, _) -> Just i
            Left _ -> Nothing
    toPathPiece = T.pack . show

instance PathPiece Int32 where
    fromPathPiece s = 
        case Data.Text.Read.decimal s of
            Right (i, _) -> Just i
            Left _ -> Nothing
    toPathPiece = T.pack . show

instance PathPiece Int64 where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece Word32 where
    fromPathPiece s =
        case Data.Text.Read.decimal s of
            Right (i, _) -> Just i
            Left _ -> Nothing

    toPathPiece = T.pack . show

instance PathPiece Word64 where
    fromPathPiece s =
        case Data.Text.Read.decimal s of
            Right (i, _) -> Just i
            Left _ -> Nothing

    toPathPiece = T.pack . show

instance PathPiece Day where
    fromPathPiece  = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance PathPiece TimeOfDay where
    fromPathPiece = safeRead
    toPathPiece = T.pack . show

instance PathPiece UTCTime where
    fromPathPiece = safeRead
    toPathPiece = T.pack . show

instance PathPiece ZonedTime where
    fromPathPiece = safeRead
    toPathPiece = T.pack . show

instance PathPiece Checkmark where
    fromPathPiece "Active" = Just Active
    fromPathPiece "Inactive" = Just Inactive
    fromPathPiece _ = Nothing
    toPathPiece Active = "Active"
    toPathPiece Inactive = "Inactive"

instance (PathPiece a, PP.PathPiece (Maybe a)) => PathPiece (Maybe a) where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

instance (PathPiece a, Show a) => PathPiece [a] where
    fromPathPiece s = do
        parts <- safeRead s
        values <- mapM fromPathPiece parts
        return values
    toPathPiece = T.pack . show

instance (ToBackendKey SqlBackend a) => PathPiece (Key a) where
    fromPathPiece x = PP.fromPathPiece x >>= (Just . toSqlKey)
    toPathPiece = PP.toPathPiece . fromSqlKey

instance PathPiece PersistValue where
    fromPathPiece = PP.fromPathPiece
    toPathPiece = PP.toPathPiece

