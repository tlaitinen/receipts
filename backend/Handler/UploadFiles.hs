{-# LANGUAGE TupleSections, OverloadedStrings #-}
module Handler.UploadFiles where

import qualified Import as I
import Import hiding (fileContentType, fileName, joinPath)
import Yesod.Auth
import Data.Time (getCurrentTime)
import qualified Data.Text as T
import Database.Persist.Sql
import Handler.Utils
import qualified Settings
import System.FilePath
import System.Directory (renameFile, removeFile, doesFileExist)
import Data.Text
import System.IO
import Handler.DB
import Data.Aeson
import System.Process
import System.Exit
import Network.HTTP.Types (status500, status403)
import System.IO.Temp (openTempFile)


convert :: String -> FilePath -> FilePath -> IO Bool
convert ext src dst = do
    let tmpDst = dst ++ "." ++ ext

    callProcess "convert" $ args ++ [src, tmpDst]
    multiplePages <- doesFileExist $ dst++ "-0." ++ ext
    if multiplePages
        then renameFile (dst ++ "-0." ++ ext) dst
        else renameFile tmpDst dst
    resultExists <- doesFileExist dst
            
    return resultExists
    where
        args
            | ext == "pdf" = ["-density", "150", "-trim", "-sharpen", "0x1.0" ]
            | otherwise = []
    

postUploadFilesR :: Handler Value
postUploadFilesR = do
    (Entity userId user) <- requireAuth

    (params, files) <- runRequestBody
    fi <- maybe notFound return $ lookup "file" files
    now <- liftIO $ getCurrentTime
    let today = utctDay now
    when (not $ isContractValid user today) $
        sendResponseStatus status400 $ object [
                "result" .= ("failed" :: Text),
                "error" .= ("no-valid-contract" :: Text)
            ] 
        
    settings<- fmap appSettings getYesod
    name <- liftIO $ do
        (fp, h) <- openTempFile (appUploadDir settings) "upload"
        hClose h
        return fp 
    liftIO $ fileMove fi name

    size <- liftIO $ withFile name ReadMode hFileSize 
        
    let fileObj = (newFile (I.fileContentType fi) 
                          (fromIntegral size)
                          (I.fileName fi)
                          now) {
            fileInsertedByUserId = Just userId,
            fileActiveStartTime = Just now
        }
    (fileId, extraFields) <- runDB $ do
        fileId' <- insert fileObj
        insert $ (newUserGroupContent $ userDefaultUserGroupId user) {
                userGroupContentFileContentId = Just $ fileId'
            }
        let fileId = fromSqlKey fileId'
        let name' = joinPath [ appUploadDir settings, show fileId]
        extraFields <- if ("preview", "jpeg") `elem` params 
            then do
                
                previewFileId <- insert $ (newFile "image/jpeg" 0 
                        (T.concat ["Preview of ", I.fileName fi]) now)
                    {
                        filePreviewOfFileId = Just fileId'
                    }
                insert $ (newUserGroupContent $ userDefaultUserGroupId user) {
                                userGroupContentFileContentId = Just $ previewFileId
                            }
                let previewName = joinPath [ appUploadDir settings, show (fromSqlKey previewFileId) ]
                success <- liftIO $ convert "jpeg" name previewName
                when (not success) $ sendResponseStatus status500 $ object [
                        "result" .= ("failed" :: Text)
                    ]
                    
                size <- liftIO $ withFile previewName ReadMode hFileSize
                update previewFileId [ FileSize =. fromIntegral size ]
    
                return [ "previewFileId" .= (toJSON previewFileId) ]
            else return []
        if (("convert", "pdf") `elem` params)
            then do
                success <- liftIO $ convert "pdf" name name'
                when (not success) $ sendResponseStatus status500 $ object [
                        "result" .= ("failed" :: Text)
                    ]
                liftIO $ removeFile name
                update fileId' [ FileContentType =. "application/pdf" ]
            else liftIO $ renameFile name name' 

        return (fileId, extraFields)
    return $ object $ [
            "result" .= ("ok" :: Text),
            "fileId" .= (toJSON fileId) 
        ] ++ extraFields

