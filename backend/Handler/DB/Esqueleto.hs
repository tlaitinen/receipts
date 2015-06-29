{-# LANGUAGE ConstraintKinds
           , FlexibleContexts
           , FlexibleInstances
           , FunctionalDependencies
           , GADTs
           , MultiParamTypeClasses
           , OverloadedStrings
           , UndecidableInstances
 #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}           
module Handler.DB.Esqueleto where
import Prelude
import Control.Applicative (Applicative(..), (<$>), (<$))
import Control.Arrow ((***), first)
import Control.Exception (throw, throwIO)
import Control.Monad ((>=>), ap, void, MonadPlus(..))
import Control.Monad.IO.Class (MonadIO(..))
import Control.Monad.Logger (MonadLogger)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Resource (MonadResourceBase)
import Data.Int 
import Data.Word
import Data.Time
import Data.List (intersperse)
import Data.Monoid (Monoid(..), (<>))
import Data.Proxy (Proxy(..))
import qualified Database.Persist as P
import qualified Control.Monad.Trans.Reader as R
import qualified Control.Monad.Trans.State as S
import qualified Control.Monad.Trans.Writer as W
import qualified Data.Conduit as C
import qualified Data.Conduit.List as CL
import qualified Data.HashSet as HS
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Builder as TLB
import qualified Data.Text.Lazy.Builder.Int as TLBI
import Data.Text (Text)
import Database.Esqueleto.Internal.Language
import Database.Esqueleto.Internal.Sql
uncommas :: [TLB.Builder] -> TLB.Builder
uncommas = mconcat . intersperse ", " . filter (/= mempty)

uncommas' :: Monoid a => [(TLB.Builder, a)] -> (TLB.Builder, a)
uncommas' = (uncommas *** mconcat) . unzip


type NegateFlag = Bool
baseDefaultFilterOp :: P.PersistField a => NegateFlag -> Text -> SqlExpr (Value a) -> SqlExpr (Value a) -> SqlExpr (Value Bool)
baseDefaultFilterOp neg op a b = if neg then not_ $ f op a b  else f op a b
    where
        f  "eq" = (==.)
        f "neq" = (!=.)
        f "lt" = (<.)
        f "gt" = (>.)
        f "le" = (<=.)
        f "ge" = (>=.)
        f "is" = is
        f "is not" = isNot 
        f _ = (==.)

textDefaultFilterOp :: (P.PersistField a) => NegateFlag -> Text -> SqlExpr (Value a) -> SqlExpr (Value a) -> SqlExpr (Value Bool)
textDefaultFilterOp neg op a b = case op of
    "like" -> if neg then not_ $ unsafe_like a b else unsafe_like a b
    "ilike" -> if neg then not_ $ unsafe_ilike a b else unsafe_ilike a b
    _ -> baseDefaultFilterOp neg op a b
class P.PersistField a => FieldFilter a where
    defaultFilterOp :: NegateFlag -> Text -> SqlExpr (Value a) -> SqlExpr (Value a) -> SqlExpr (Value Bool)
    defaultFilterOp = baseDefaultFilterOp
instance FieldFilter Text where
    defaultFilterOp = textDefaultFilterOp
instance FieldFilter (Maybe Text) where
    defaultFilterOp = textDefaultFilterOp


instance P.PersistEntity a => FieldFilter (P.Key a) where
instance FieldFilter P.Checkmark where
instance FieldFilter Double where
instance FieldFilter Word32 where
instance FieldFilter Word64 where
instance FieldFilter Int32 where
instance FieldFilter Int64 where
instance FieldFilter Int where
instance FieldFilter Day where
instance FieldFilter TimeOfDay where
instance FieldFilter UTCTime where
instance FieldFilter Bool where
instance P.PersistEntity a => FieldFilter (Maybe (P.Key a)) where
instance FieldFilter (Maybe P.Checkmark) where
instance FieldFilter (Maybe Double) where
instance FieldFilter (Maybe Word32) where
instance FieldFilter (Maybe Word64) where
instance FieldFilter (Maybe Int32) where
instance FieldFilter (Maybe Int64) where
instance FieldFilter (Maybe Int) where
instance FieldFilter (Maybe Day) where
instance FieldFilter (Maybe TimeOfDay) where
instance FieldFilter (Maybe UTCTime) where
instance FieldFilter (Maybe Bool) where
instance FieldFilter (Maybe a) => FieldFilter (Maybe (Maybe a)) where
    defaultFilterOp neg op a b = defaultFilterOp neg op (joinV a) (joinV b)

is = unsafeSqlBinOp " IS "
isNot = unsafeSqlBinOp " IS NOT "
unsafe_like = unsafeSqlBinOp " LIKE "
unsafe_ilike = unsafeSqlBinOp " ILIKE "

extractSubField :: UnsafeSqlFunctionArgument a => TLB.Builder -> a -> SqlExpr (Value Double)
extractSubField = unsafeSqlExtractSubField
