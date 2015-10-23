{-# LANGUAGE TupleSections, OverloadedStrings #-}
module Handler.Mailgun where

import qualified Import as I
import Import hiding (fileContentType, fileName, joinPath, isNothing)
import Yesod.Auth
import Data.Time (getCurrentTime)
import Database.Esqueleto hiding ((=.), update)
import qualified Data.Text as T
import Database.Persist.Sql
import qualified Settings
import System.FilePath
import System.Directory (renameFile, removeFile, doesFileExist)
import Data.Text
import System.IO
import Handler.DB
import Data.Aeson
import System.Process
import System.Exit
import Network.HTTP.Types (status406)
import System.IO.Temp (openTempFile)
import qualified Data.List as L
import qualified Data.Text.Read as DTR
import Network.Mail.SMTP
import Network.Mail.Mime
import qualified Handler.UploadFiles as UF
import qualified Data.Text.Lazy as LT
postMailgunR :: Handler ()
postMailgunR = do
    (params, files) <- runRequestBody
    liftIO $ I.print params
    case (param params "From", param params "To") of
        (Just fromAddr, Just toAddr) -> runDB $ do
            let toUserName = extractUserName toAddr
            users <- select $ from $ \u -> do
                where_ $ u ^. UserName `ilike` val toUserName
                where_ $ isNothing $ u ^. UserDeletedVersionId 
                return u
            case listToMaybe users of
                Just user@(Entity _ u) -> if userEmail u `T.isInfixOf` fromAddr || userStrictEmailCheck u == False
                    then receiveFiles user files
                    else reject params
                Nothing -> reject params   
        _ -> reject params
    where
        extractUserName addr
            | T.count "<" addr > 0 = let (_,rest) = T.breakOn "<" addr
                                         (addr',_) = T.breakOn ">" $ T.drop 1 rest
                                         in dropDomain addr'
            | otherwise = dropDomain addr                            
        dropDomain = T.takeWhile (/= '@')
        param params p = fmap snd $ L.find ((==p) . fst)  params
        reject params = do
            settings <- fmap appSettings getYesod
            case param params "From" of
                Just fromAddr -> liftIO $ sendMail (appSmtpAddress settings) $ simpleMail'
                    (Address Nothing fromAddr)
                    (Address Nothing $ appSenderEmail settings)
                    "Delivery Status Notification (Failure)" (failureMessage params)
                Nothing -> return ()    
            sendResponseStatus status406 ()             
        failureMessage params = LT.fromChunks [
                "Delivery to the following recipient failed permanently:\n\n",
                fromMaybe "" $ (param params "To"),
                "\n\n",
                "Please check the destination address and make sure that the sender address ",
                fromMaybe "" $ (param params "From"),
                " is allowed to send messages to the destination address.\n\n",
                "---- Original message ----\n\n", 
                T.concat [ T.concat [ k, ": ", v, "\n"] | (k,v) <- params ]
            ]
        parseDouble s 
            | T.count "." s == 1 = case DTR.double s of
                Right (i, _) -> Just i
                Left _ -> Nothing    
            | otherwise = Nothing    
        parseAmount fn = let (base, _) = splitExtension $ T.unpack fn 
                             parts     = T.split (`elem` [' ', '_', '-']) $ T.pack base
                             (skip,amount) = fromMaybe (-1,0.0) $ listToMaybe $ I.reverse $ catMaybes [ 
                                    parseDouble (T.replace "," "." p) 
                                    >>= Just . (i,)| (i,p) <- I.zip [0..] parts 
                                ]
                             name = T.intercalate " " [ p | (i,p) <- I.zip [0..] parts, i /= skip ]
                             in (name, amount)

        receiveFiles (Entity userId user) files = do
            now <- liftIO $ getCurrentTime
            settings<- fmap appSettings getYesod
            forM_ files $ \(_,fi) -> do
                tmpName <- liftIO $ do
                    (fp, h) <- openTempFile (appUploadDir settings) "upload"
                    hClose h
                    return fp 
                liftIO $ fileMove fi tmpName

                size <- liftIO $ withFile tmpName ReadMode hFileSize 
                    
                let fileObj = (newFile (I.fileContentType fi) 
                                      (fromIntegral size)
                                      (I.fileName fi)
                                      now) {
                        fileInsertedByUserId = Just userId,
                        fileActiveStartTime = Just now
                    }
                fileId <- insert fileObj
                insert $ (newUserGroupContent $ userDefaultUserGroupId user) {
                        userGroupContentFileContentId = Just $ fileId
                    }
                let fileId' = fromSqlKey fileId
                let name = joinPath [ appUploadDir settings, show fileId']
                        
                if (I.fileContentType fi `elem` ["image/png", "image/gif", "image/jpeg", "image/bmp", "image/tiff", "application/pdf" ]) 
                    then do
                        previewFileId <- insert $ (newFile "image/jpeg" 0 
                                (T.concat ["Preview of ", I.fileName fi]) now)
                            {
                                filePreviewOfFileId = Just fileId
                            }
                        insert $ (newUserGroupContent $ userDefaultUserGroupId user) {
                                        userGroupContentFileContentId = Just $ previewFileId
                                    }
                        let previewName = joinPath [ appUploadDir settings, show (fromSqlKey previewFileId) ]
                        success <- liftIO $ UF.convert "jpeg" tmpName previewName
                        when success $ do
                            size <- liftIO $ withFile previewName ReadMode hFileSize
                            update previewFileId [ FileSize =. fromIntegral size ]
                            success <- liftIO $ UF.convert "pdf" tmpName name
                            liftIO $ removeFile tmpName
                            update fileId [ FileContentType =. "application/pdf" ]
                    else liftIO $ renameFile tmpName name                                
                         
                let origName = I.fileName fi            
                    (rName, amount) = parseAmount origName
                rId <- insert $ (newReceipt fileId amount rName now) {
                        receiptInsertedByUserId = Just userId,
                        receiptActiveStartTime = Just now
                    }
                _ <- insert $ (newUserGroupContent $ userDefaultUserGroupId user) {
                        userGroupContentReceiptContentId = Just rId
                    }
                return ()

