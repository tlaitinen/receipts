{-# LANGUAGE FlexibleInstances #-}

module Handler.DB.FilterSort where
import qualified Handler.DB.PathPieces as PP
import Prelude
import Data.Text (Text)
import Data.Maybe
import Data.Aeson
import Data.Aeson.TH
import Data.String
import Control.Monad
import Control.Applicative
import qualified Data.List as L
import qualified Data.Text as T
import qualified Data.Aeson.Types as AT
import qualified Data.HashMap.Strict as HMS

data Filter = Filter {
    f_type :: Text,
    f_value :: Maybe Text,
    f_field :: Maybe Text,
    f_comparison :: Text,
    f_negate :: Bool,
    f_exprs :: [Filter]
} 

instance FromJSON Filter where
    parseJSON (Object v) = Filter 
        <$> v .:? "type" .!= "string" 
        <*> (parseStringOrInt v) 
        <*> (v .: "field" <|>  v .: "property")
        <*> v .:? "comparison" .!= "eq" 
        <*> v .:? "negate" .!= False
        <*> v .:? "exprs" .!= []
    parseJSON _ = mzero

instance IsString (Maybe Text) where
    fromString "" = Nothing
    fromString a  = Just $ T.pack a

parseStringOrInt :: HMS.HashMap Text Value -> AT.Parser (Maybe Text)
parseStringOrInt hm = case HMS.lookup "value" hm of
    Just (Number n) -> return $ Just $ T.pack $ show n
    Just (String s) -> return $ Just s 
    Just (Null) -> return Nothing
    _ -> mzero

data Sort = Sort {
    s_field :: Text,
    s_direction :: Text
}
instance FromJSON Sort where
    parseJSON (Object v) = Sort 
        <$> (v .: "field" <|> v .: "property")
        <*> (v .: "direction")
        
    parseJSON _ = mzero


getDefaultFilter maybeGetParam defaultFilter p = do
    f <- maybe maybeGetParam id getFilter
    PP.fromPathPiece f
    where 
        getFilter = do            
            j <- defaultFilter
            v <- L.find (\fjm -> f_field fjm == p) j
            return (f_value v)
hasDefaultFilter maybeGetParam defaultFilter p = isJust $
    maybe maybeGetParam id getFilter
    where
        getFilter = do
            j <- defaultFilter
            v <- L.find (\fjm -> f_field fjm == p) j
            return (f_value v)
