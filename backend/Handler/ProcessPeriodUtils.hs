{-# LANGUAGE RankNTypes #-}
module Handler.ProcessPeriodUtils where
import Import hiding ((>=.), (==.), isNothing)
import Control.Monad.Logger (LoggingT)
import Data.Time
import Handler.DB
import qualified Data.Text as T
import Database.Esqueleto


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
    _ -> MsgJanuary
    where
        (_, month, _) = toGregorian d 


createAllProcessPeriods :: forall (m :: * -> *). MonadIO m => ReaderT SqlBackend m ()
createAllProcessPeriods = do
       
    ugs <- select $ from $ \ug -> do
        where_ $ ug ^. UserGroupCreatePeriods >=. val 0
        where_ $ isNothing $ ug ^. UserGroupDeletedVersionId
        return ug        
        
    forM_ ugs createProcessPeriods
    
createProcessPeriods :: forall (m :: * -> *). MonadIO m => Entity UserGroup -> ReaderT SqlBackend m ()
createProcessPeriods (Entity ugId ug) = do
    now <- liftIO $ getCurrentTime
    let today = utctDay now
        (todayYear, todayMonth, _) = toGregorian today
        firstDay periods = addGregorianMonthsRollOver (-periods)
                                      (fromGregorian todayYear todayMonth 1)
 
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

