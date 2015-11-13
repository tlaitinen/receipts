{-# LANGUAGE TupleSections, OverloadedStrings #-}
module Handler.SetUserPassword (postSetUserPasswordR, postSetUserPasswordTokenR) where
import Data.Time
import Import 
import Handler.DB
import Network.HTTP.Types (status400)
import Control.Monad
import Yesod.Auth
import Yesod.Auth.HashDB (setPassword)
import qualified Data.Aeson as A
postSetUserPasswordTokenR :: UserId -> Text -> Handler ()
postSetUserPasswordTokenR userId token = do
    password <- lookupPostParam ("password"::Text)
    case password of
        Just pw -> do
            maybeUser <- runDB $ get userId
            case maybeUser of
                Just user -> do
                    now <- liftIO getCurrentTime
                    if userPasswordResetToken user == Just token 
                            && liftM2 (>) (userPasswordResetValidUntil user) (Just now) == Just True
                        then do
                            user' <- liftIO $ setPassword pw user
                            runDB $ update userId [ 
                                    UserPassword =. userPassword user',
                                    UserSalt     =. userSalt user',
                                    UserPasswordResetToken =. Nothing,
                                    UserPasswordResetValidUntil =. Nothing
                                ]
                        else reply "Invalid password reset token"        
                Nothing -> reply "User not found"
        Nothing -> reply "Missing required parameter 'password'"
    where reply msg = 
            sendResponseStatus status400 $ A.object [ "error" .= (msg :: Text)]
                    
 
 
postSetUserPasswordR :: UserId -> Handler ()
postSetUserPasswordR userId = do
    (Entity authId auth) <- requireAuth
    if authId == userId || userAdmin auth 
        then do
            password <- lookupPostParam ("password"::Text)
            case password of
                Just pw -> do
                    maybeUser <- runDB $ get userId
                    case maybeUser of
                        Just user -> do
                            user' <- liftIO $ setPassword pw user
                            runDB $ update userId [ 
                                    UserPassword =. userPassword user',
                                    UserSalt     =. userSalt user'
                                ]
                        Nothing -> reply "User not found"
                Nothing -> reply "Missing required parameter 'password'"
        else reply "Unauthorized password change attempt"
    where reply msg = 
            sendResponseStatus status400 $ A.object [ "error" .= (msg :: Text)]
                    
 
                            
