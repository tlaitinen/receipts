module Handler.Encoding (toAscii) where
import Prelude
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Lazy.Encoding as LTE
import Data.Text (Text)
import Codec.Text.IConv (convert)

toAscii :: Text -> Text
toAscii = LT.toStrict
    . LTE.decodeUtf8 
    . (convert "UTF-8" "ASCII//TRANSLIT") 
    . LTE.encodeUtf8
    . LT.fromStrict





