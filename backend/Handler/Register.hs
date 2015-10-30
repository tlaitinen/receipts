{-# LANGUAGE TupleSections, OverloadedStrings #-}
module Handler.Register where
import Yesod.Auth
import Import
import Handler.DB
import Data.Time.Clock.POSIX
import Yesod.ReCAPTCHA
import Network.HTTP.Types (status400)
import qualified Data.Aeson as A
import Data.Aeson.TH
import Handler.Utils
import qualified Data.Text as T
data Params = Params {
    p_firstName :: Text,
    p_lastName  :: Text,
    p_organization :: Text,
    p_email     :: Text,
    p_recaptchaResponse  :: Text
} 
$(deriveJSON defaultOptions{fieldLabelModifier = drop 2} ''Params)

postRegisterR :: Handler Value
postRegisterR = do 
    jr <- parseJsonBody
    p <- case jr of
        A.Error err -> sendResponseStatus status400 $ A.object [
                "success" .= False,
                "error" .= err
            ]
        A.Success p -> return p
    ip <- getIp
    r <- recaptchaCheck (T.unpack $ fromMaybe "" ip) "manual-challenge" (p_recaptchaResponse p)
    case r of
        RecaptchaOk -> return $ object [ "success" .= True ]
        RecaptchaError err -> sendResponseStatus status400 $ A.object [
                "success" .= False,
                "error" .= err
            ]
        
