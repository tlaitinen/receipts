{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
import Prelude ()
import System.IO.Temp
import Text.Blaze.Html.Renderer.Text (renderHtml)
import Text.Hamlet
import Settings           
import Data.Double.Conversion.Text as DCT
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import qualified Data.ByteString.Lazy as LB
import Text.Printf
import Data.Maybe (fromMaybe)
import qualified Database.Persist
import Import hiding (Option, (==.), (>=.), isNothing, update, (=.), on, joinPath, fileSize, fileContentType) 
import System.Console.GetOpt
import Control.Monad.Trans.Resource (runResourceT, ResourceT)
import Database.Persist.Postgresql          (createPostgresqlPool, pgConnStr,
                                             pgPoolSize, runSqlPool)
import Control.Monad.Logger (runStdoutLoggingT, LoggingT)
import Control.Concurrent 
import Handler.DB
import Handler.ProcessPeriodUtils
import Database.Esqueleto
import qualified Database.Esqueleto as E
import Data.Time.Clock (getCurrentTime, addUTCTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)

import qualified Control.Exception as E
import System.Exit
import qualified Data.Map as Map
import Data.Time
import Codec.Archive.Zip
import Network.Mail.SMTP (sendMail)
import Network.Mail.Mime
import System.FilePath
import qualified Data.Text.Encoding as TE
import Network.Mime (MimeMap, defaultMimeMap)

invMimeMap :: Map.Map Text Text
invMimeMap = Map.fromList $ [ (TE.decodeUtf8 v,k) | (k,v) <- Map.toList defaultMimeMap ]  ++ [ ("text/html", "html") ]

ctypeToExt :: Text -> Text
ctypeToExt ctype = Map.findWithDefault "unknown" ctype invMimeMap

minuteRun :: AppSettings -> SqlPersistT (LoggingT IO) ()
minuteRun settings = do
    createAllProcessPeriods
    processQueuedPeriods settings

packReceipts :: AppSettings -> [(Entity Receipt, Entity File)] -> IO [Archive]
packReceipts settings receipts = pack emptyArchive receipts
    where
        used a = fromIntegral $ sum [ eCompressedSize e | e <- zEntries a ]
        fits a f = used a + fromIntegral (fileSize f) < appMaxEmailSize settings
        path fId = joinPath [ appUploadDir settings, show $ fromSqlKey fId ]
        mtime = floor . utcTimeToPOSIXSeconds . fileInsertionTime
        shortenName x = T.pack $ take (appMaxZipEntryLength settings - 11) (T.unpack x)

        receiptPath r f = T.unpack $ T.concat [ shortenName (receiptName r), 
                                                "_", T.pack $ show $ receiptAmount r, ".", ctypeToExt (fileContentType f) ]
        pack a rs'@((Entity _ r, Entity fId f):rs) 
            | fits a f = do
                contents <- LB.readFile $ path fId
                let entry = toEntry (receiptPath r f) (mtime f) contents
                pack (addEntryToArchive entry a) rs
            | otherwise = do
                a' <- pack emptyArchive rs'
                return $ a:a'
        pack a [] = return [a]

processQueuedPeriods :: AppSettings -> SqlPersistT (LoggingT IO) ()
processQueuedPeriods settings = do
    pps <- select $ from $ \(pp `InnerJoin` ugc `InnerJoin` ug)-> do
        on (ugc ^. UserGroupContentUserGroupId ==. ug ^. UserGroupId)
        on (ugc ^. UserGroupContentProcessPeriodContentId ==. just (pp ^. ProcessPeriodId))
        where_ $ pp ^. ProcessPeriodQueued ==. val True
        where_ $ isNothing $ ugc ^. UserGroupContentDeletedVersionId
        return (pp, ugc ^. UserGroupContentUserGroupId, ug)

    forM_ pps $ \(Entity ppId pp, E.Value ugId, Entity _ ug) -> do
        receipts <- select $ from $ \(r `InnerJoin` f)-> do
            on (f ^. FileId ==. r ^. ReceiptFileId)
            where_ $ r ^. ReceiptProcessed ==. val False
            where_ $ r ^. ReceiptProcessPeriodId ==. val (Just ppId)
            where_ $ isNothing $ r ^. ReceiptDeletedVersionId
            orderBy $ [ asc (r ^. ReceiptAmount) ]
            return (r,f)        
        archives <- liftIO $ packReceipts settings receipts    

        let firstDay = processPeriodFirstDay pp
            lastDay  = processPeriodLastDay pp
        forM_ (zip [1..] archives) $ \(part,a) -> liftIO $ withSystemTempDirectory "receipts" $ \tempDir -> do
            let tmpPath = tempDir </> (concat [ T.unpack $ userGroupName ug, "_", show firstDay, "_", show lastDay, ".zip"])
                app = (error "" :: App)
                partInfo = T.pack $ if length archives > 1 then concat ["(", show part, " / ", show $ length archives, ")" ] else ""
                msg = if processPeriodProcessed pp == False
                        then MsgReceiptEmailTitle (userGroupName ug)  firstDay lastDay partInfo
                        else MsgMoreReceiptsEmailTitle (userGroupName ug)  firstDay lastDay partInfo
                message = renderMessage app ["fi"] msg 
            LB.writeFile tmpPath (fromArchive a)        
            mail <- simpleMail 
                (Address (Just $ userGroupName ug) (userGroupEmail ug))
                (Address Nothing $ appSenderEmail settings)
                message (textBody message receipts) (htmlBody message receipts)
                [("application/zip", tmpPath)] 
            sendMail (appSmtpAddress settings) mail
        update $ \pp' -> do
            where_ $ pp' ^. ProcessPeriodId ==. val ppId
            set pp' [ 
                    ProcessPeriodProcessed =. val True,
                    ProcessPeriodQueued =. val False
                ]
        forM_ receipts $ \(Entity rId _, _) -> update $ \r -> do
            set r [ ReceiptProcessed =. val True ]
            where_ $ r ^. ReceiptId ==. val rId
    where
        textBody title receipts = LT.fromChunks $ [title, "\n\n"] ++ concat [ 
                [ pad 8 $ DCT.toFixed 2 (receiptAmount r), 
                  " ", receiptName r, "\n" ]
                  | ((Entity _ r), _) <- receipts 
            ] 
        htmlBody :: Text -> [(Entity Receipt, Entity File)] -> LT.Text
        htmlBody title receipts = renderHtml $ $(hamletFile "templates/receipts.hamlet") "HTML" 
        pad x s
            | T.length s < x = T.concat [ T.replicate (x - T.length s) " ", s ]
            | otherwise = s 
        mySimpleMail to from subject plain html attachments = do
            let m = ((emptyMail from) { mailTo = [to]
                                 , mailHeaders = [("Subject", subject)]
                                                      })
            m' <- addAttachments attachments m
            return $ addPart [htmlPart html, plainPart plain] m'   
             
main :: IO ()
main = do
    settings <- loadAppSettings [configSettingsYml] [] useEnv
    pool <- runStdoutLoggingT $ createPostgresqlPool
        (pgConnStr  $ appDatabaseConf settings)
        (pgPoolSize $ appDatabaseConf settings)
    runStdoutLoggingT (runSqlPool (minuteRun settings) pool)

