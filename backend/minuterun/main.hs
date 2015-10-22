{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
import Prelude ()
import System.IO.Temp
import Settings           
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import qualified Data.ByteString.Lazy as LB
import Text.Printf
import Data.Maybe (fromMaybe)
import qualified Database.Persist
import Import hiding (Option, (==.), (>=.), isNothing, update, (=.), on, joinPath, fileSize) 
import System.Console.GetOpt
import Control.Monad.Trans.Resource (runResourceT, ResourceT)
import Database.Persist.Postgresql          (createPostgresqlPool, pgConnStr,
                                             pgPoolSize, runSqlPool)
import Control.Monad.Logger (runStdoutLoggingT, LoggingT)
import Control.Concurrent 
import Handler.DB
import Database.Esqueleto
import qualified Database.Esqueleto as E
import Data.Time.Clock (getCurrentTime, addUTCTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)

import qualified Control.Exception as E
import System.Exit
import qualified Data.Map as Map
import Data.Time
import Codec.Archive.Zip
import Network.Mail.SMTP
import Network.Mail.Mime
import System.FilePath

fmtDay :: Day -> Text
fmtDay day = T.pack $ printf "%d.%d.%d" d m (y `mod` 100)
    where (y,m,d) = toGregorian day

mkMessage "App" "messages" "fi"

minuteRun :: AppSettings -> SqlPersistT (LoggingT IO) ()
minuteRun settings = do
    createProcessPeriods
    processQueuedPeriods settings



periodDatesRange :: Day -> Day -> [(Day,Day)]
periodDatesRange start end
    | sDay > 1 = periodDatesRange next end
    | monthEnd < end = (start, monthEnd) : periodDatesRange next end
    | otherwise = [(start,monthEnd)]
    where
        (sYear, sMonth, sDay) = toGregorian start
        next = addGregorianMonthsRollOver 1 (fromGregorian sYear sMonth 1)
        monthEnd = fromGregorian sYear sMonth (gregorianMonthLength sYear sMonth)
monthName :: [Text] -> Day -> Text
monthName langs d = renderMessage (error "" :: App) langs $ case month of
    1 -> MsgJanuary
    2 -> MsgFebruary
    3 -> MsgMarch
    4 -> MsgApril
    5 -> MsgMay
    6 -> MsgJune
    7 -> MsgJuly
    8 -> MsgAugust
    9 -> MsgSeptember
    10 -> MsgOctober
    11 -> MsgNovember
    12 -> MsgDecember
    where
        (_, month, _) = toGregorian d 
createProcessPeriods :: SqlPersistT (LoggingT IO) () 
createProcessPeriods = do
    now <- liftIO $ getCurrentTime
    let today = utctDay now
        (todayYear, todayMonth, _) = toGregorian today
        firstDay periods = addGregorianMonthsRollOver (-periods)
                                      (fromGregorian todayYear todayMonth 1)
        
        
    ugs <- select $ from $ \ug -> do
        where_ $ ug ^. UserGroupCreatePeriods >=. val 0
        where_ $ isNothing $ ug ^. UserGroupDeletedVersionId
        return ug        
    forM_ ugs $ \(Entity ugId ug) -> do
        let periods = periodDatesRange (firstDay $ fromIntegral $ userGroupCreatePeriods ug) today
        forM_ periods $ \(fDay, lDay) -> void $ do
            rows <- select $ from $ \pp -> do
                where_ $ pp ^. ProcessPeriodFirstDay ==. val fDay
                where_ $ pp ^. ProcessPeriodLastDay ==. val lDay
                where_ $ exists $ from $ \ugc -> do
                    where_ $ ugc ^. UserGroupContentUserGroupId ==. val ugId
                    where_ $ ugc ^. UserGroupContentProcessPeriodContentId ==. just (pp ^. ProcessPeriodId)
                    where_ $ isNothing $ ugc ^. UserGroupContentDeletedVersionId            
                return $ pp ^. ProcessPeriodId
            when (null rows) $ do
                let
                    (year, _, _) = toGregorian fDay
                    name = T.concat [ monthName ["fi"] fDay, " ", T.pack $ show year ]
                ppId <- insert $ newProcessPeriod fDay lDay name
                _ <- insert $ (newUserGroupContent ugId) {
                        userGroupContentProcessPeriodContentId = Just ppId
                    }
                return ()    

packReceipts :: AppSettings -> [(Entity Receipt, Entity File)] -> IO [Archive]
packReceipts settings receipts = pack emptyArchive receipts
    where
        used a = fromIntegral $ sum [ eCompressedSize e | e <- zEntries a ]
        fits a f = used a + fromIntegral (fileSize f) < appMaxEmailSize settings
        path fId = joinPath [ appUploadDir settings, show $ fromSqlKey fId ]
        mtime = floor . utcTimeToPOSIXSeconds . fileInsertionTime
        receiptPath r = T.unpack $ T.concat [ receiptName r, "_", T.pack $ show $ receiptAmount r, ".pdf" ]
        pack a rs'@((Entity _ r, Entity fId f):rs) 
            | fits a f = do
                contents <- LB.readFile $ path fId
                let entry = toEntry (receiptPath r) (mtime f) contents
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
            mail <- mySimpleMail 
                (Address (Just $ userGroupName ug) (userGroupEmail ug))
                (Address Nothing $ appSenderEmail settings)
                message (LT.fromChunks [message])
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
        mySimpleMail to from subject plainBody attachments = do
            let m = ((emptyMail from) { mailTo = [to]
                                 , mailHeaders = [("Subject", subject)]
                                                      })
            m' <- addAttachments attachments m
            return $ addPart [plainPart plainBody] m'   
             
main :: IO ()
main = do
    settings <- loadAppSettings [configSettingsYml] [] useEnv
    pool <- runStdoutLoggingT $ createPostgresqlPool
        (pgConnStr  $ appDatabaseConf settings)
        (pgPoolSize $ appDatabaseConf settings)
    runStdoutLoggingT (runSqlPool (minuteRun settings) pool)

