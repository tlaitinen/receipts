{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# OPTIONS_GHC -fno-warn-overlapping-patterns #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}
{-# OPTIONS_GHC -fno-warn-unused-binds #-}
{-# OPTIONS_GHC -fno-warn-unused-matches #-}
module Handler.DB.Internal where
import Handler.DB.Enums
import Handler.DB.Esqueleto
import qualified Handler.DB.PathPieces as PP
import Prelude
import Control.Monad (forM_, when)
import Control.Monad.Catch (MonadThrow)
import Control.Monad.Trans.Maybe (MaybeT(..), runMaybeT)
import Database.Esqueleto
import qualified Database.Esqueleto as E
import qualified Database.Persist as P
import Database.Persist.TH
import Yesod.Auth (requireAuth, requireAuthId, YesodAuth, AuthId, YesodAuthPersist)
import Yesod.Core hiding (fileName, fileContentType)
import Yesod.Persist (runDB, YesodPersist, YesodPersistBackend)
import Data.Aeson ((.:), (.:?), (.!=), FromJSON, parseJSON, decode)
import Data.Aeson.TH
import Data.Int
import Data.Word
import Data.Time
import Data.Text.Encoding (encodeUtf8)
import Data.Typeable (Typeable)
import qualified Data.Attoparsec as AP
import qualified Data.Aeson as A
import qualified Data.Aeson.Types as AT
import qualified Data.ByteString.Lazy as LBS
import Data.Maybe
import qualified Data.Text.Read
import qualified Data.Text as T
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.List as DL
import Control.Monad (mzero)
import Control.Monad.Trans.Resource (runResourceT)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as L
import qualified Network.HTTP.Conduit as C
import qualified Network.Wai as W
import Data.Conduit.Lazy (lazyConsume)
import Network.HTTP.Types (status200, status400, status403, status404)
import Blaze.ByteString.Builder.ByteString (fromByteString)
import Control.Applicative ((<$>), (<*>))  
import qualified Data.HashMap.Lazy as HML
import qualified Data.HashMap.Strict as HMS
import qualified Data.Text.Lazy.Builder as TLB
data DB = DB


share [mkPersist sqlSettings, mkMigrate "migrateDB" ] [persistLowerCase|
File json
    contentType Text  
    size Int32  
    previewOfFileId FileId Maybe   default=NULL
    name Text  
    activeId FileId Maybe   default=NULL
    activeStartTime UTCTime Maybe  
    activeEndTime UTCTime Maybe  
    deletedVersionId VersionId Maybe   default=NULL
    insertionTime UTCTime  
    insertedByUserId UserId Maybe   default=NULL
UserGroupContent json
    userGroupId UserGroupId  
    fileContentId FileId Maybe   default=NULL
    userGroupContentId UserGroupId Maybe   default=NULL
    userContentId UserId Maybe   default=NULL
    receiptContentId ReceiptId Maybe   default=NULL
    processPeriodContentId ProcessPeriodId Maybe   default=NULL
    deletedVersionId VersionId Maybe   default=NULL
UserGroup json
    createPeriods Int32  "default=1"
    email Text  "default=''"
    organization Text Maybe  
    current Checkmark  "default=True" nullable
    name Text  
    activeId UserGroupId Maybe   default=NULL
    activeStartTime UTCTime Maybe  
    activeEndTime UTCTime Maybe  
    deletedVersionId VersionId Maybe   default=NULL
    UniqueUserGroup current name !force
UserGroupItem json
    userGroupId UserGroupId  
    userId UserId  
    mode UserGroupMode  
    deletedVersionId VersionId Maybe   default=NULL
User json
    firstName Text  "default=''"
    lastName Text  "default=''"
    organization Text  "default=''"
    admin Bool  "default=False"
    email Text  "default=''"
    password Text  "default=''"
    salt Text  "default=''"
    passwordResetToken Text Maybe  
    passwordResetValidUntil UTCTime Maybe  
    contractStartDate Day Maybe  
    contractEndDate Day Maybe  
    defaultUserGroupId UserGroupId  
    timeZone Text  "default='Europe/Helsinki'"
    current Checkmark  "default=True" nullable
    config Text  "default='{}'"
    strictEmailCheck Bool  "default=False"
    name Text  
    activeId UserId Maybe   default=NULL
    activeStartTime UTCTime Maybe  
    activeEndTime UTCTime Maybe  
    deletedVersionId VersionId Maybe   default=NULL
    UniqueUser current name !force
    deriving Typeable
Version json
    time UTCTime  
    userId UserId  
Receipt json
    fileId FileId  
    processPeriodId ProcessPeriodId Maybe   default=NULL
    amount Double  
    processed Bool  "default=False"
    name Text  
    activeId ReceiptId Maybe   default=NULL
    activeStartTime UTCTime Maybe  
    activeEndTime UTCTime Maybe  
    deletedVersionId VersionId Maybe   default=NULL
    insertionTime UTCTime  
    insertedByUserId UserId Maybe   default=NULL
ProcessPeriod json
    firstDay Day  
    lastDay Day  
    queued Bool  "default=False"
    processed Bool  "default=False"
    name Text  
|]
newFile :: Text -> Int32 -> Text -> UTCTime -> File
newFile contentType_ size_ name_ insertionTime_ = File {
    fileContentType = contentType_,
    fileSize = size_,
    filePreviewOfFileId = Nothing,
    fileName = name_,
    fileActiveId = Nothing,
    fileActiveStartTime = Nothing,
    fileActiveEndTime = Nothing,
    fileDeletedVersionId = Nothing,
    fileInsertionTime = insertionTime_,
    fileInsertedByUserId = Nothing
}    
newUserGroupContent :: UserGroupId -> UserGroupContent
newUserGroupContent userGroupId_ = UserGroupContent {
    userGroupContentUserGroupId = userGroupId_,
    userGroupContentFileContentId = Nothing,
    userGroupContentUserGroupContentId = Nothing,
    userGroupContentUserContentId = Nothing,
    userGroupContentReceiptContentId = Nothing,
    userGroupContentProcessPeriodContentId = Nothing,
    userGroupContentDeletedVersionId = Nothing
}    
newUserGroup :: Text -> UserGroup
newUserGroup name_ = UserGroup {
    userGroupCreatePeriods = 1,
    userGroupEmail = "",
    userGroupOrganization = Nothing,
    userGroupCurrent = Active,
    userGroupName = name_,
    userGroupActiveId = Nothing,
    userGroupActiveStartTime = Nothing,
    userGroupActiveEndTime = Nothing,
    userGroupDeletedVersionId = Nothing
}    
newUserGroupItem :: UserGroupId -> UserId -> UserGroupMode -> UserGroupItem
newUserGroupItem userGroupId_ userId_ mode_ = UserGroupItem {
    userGroupItemUserGroupId = userGroupId_,
    userGroupItemUserId = userId_,
    userGroupItemMode = mode_,
    userGroupItemDeletedVersionId = Nothing
}    
newUser :: UserGroupId -> Text -> User
newUser defaultUserGroupId_ name_ = User {
    userFirstName = "",
    userLastName = "",
    userOrganization = "",
    userAdmin = False,
    userEmail = "",
    userPassword = "",
    userSalt = "",
    userPasswordResetToken = Nothing,
    userPasswordResetValidUntil = Nothing,
    userContractStartDate = Nothing,
    userContractEndDate = Nothing,
    userDefaultUserGroupId = defaultUserGroupId_,
    userTimeZone = "Europe/Helsinki",
    userCurrent = Active,
    userConfig = "{}",
    userStrictEmailCheck = False,
    userName = name_,
    userActiveId = Nothing,
    userActiveStartTime = Nothing,
    userActiveEndTime = Nothing,
    userDeletedVersionId = Nothing
}    
newVersion :: UTCTime -> UserId -> Version
newVersion time_ userId_ = Version {
    versionTime = time_,
    versionUserId = userId_
}    
newReceipt :: FileId -> Double -> Text -> UTCTime -> Receipt
newReceipt fileId_ amount_ name_ insertionTime_ = Receipt {
    receiptFileId = fileId_,
    receiptProcessPeriodId = Nothing,
    receiptAmount = amount_,
    receiptProcessed = False,
    receiptName = name_,
    receiptActiveId = Nothing,
    receiptActiveStartTime = Nothing,
    receiptActiveEndTime = Nothing,
    receiptDeletedVersionId = Nothing,
    receiptInsertionTime = insertionTime_,
    receiptInsertedByUserId = Nothing
}    
newProcessPeriod :: Day -> Day -> Text -> ProcessPeriod
newProcessPeriod firstDay_ lastDay_ name_ = ProcessPeriod {
    processPeriodFirstDay = firstDay_,
    processPeriodLastDay = lastDay_,
    processPeriodQueued = False,
    processPeriodProcessed = False,
    processPeriodName = name_
}    
class Named a where
    namedName :: a -> Text
data NamedInstanceFieldName = NamedName 
instance Named File where
    namedName = fileName
instance Named UserGroup where
    namedName = userGroupName
instance Named User where
    namedName = userName
instance Named Receipt where
    namedName = receiptName
instance Named ProcessPeriod where
    namedName = processPeriodName
data NamedInstance = NamedInstanceFile (Entity File)
    | NamedInstanceUserGroup (Entity UserGroup)
    | NamedInstanceUser (Entity User)
    | NamedInstanceReceipt (Entity Receipt)
    | NamedInstanceProcessPeriod (Entity ProcessPeriod)


data NamedInstanceId = NamedInstanceFileId FileId
    | NamedInstanceUserGroupId UserGroupId
    | NamedInstanceUserId UserId
    | NamedInstanceReceiptId ReceiptId
    | NamedInstanceProcessPeriodId ProcessPeriodId
    deriving (Eq, Ord)

reflectNamedInstanceId :: NamedInstanceId -> (Text, Int64)
reflectNamedInstanceId x = case x of
    NamedInstanceFileId key -> ("File", fromSqlKey key)
    NamedInstanceUserGroupId key -> ("UserGroup", fromSqlKey key)
    NamedInstanceUserId key -> ("User", fromSqlKey key)
    NamedInstanceReceiptId key -> ("Receipt", fromSqlKey key)
    NamedInstanceProcessPeriodId key -> ("ProcessPeriod", fromSqlKey key)


instance Named NamedInstance where
    namedName x = case x of
        NamedInstanceFile (Entity _ e) -> fileName e
        NamedInstanceUserGroup (Entity _ e) -> userGroupName e
        NamedInstanceUser (Entity _ e) -> userName e
        NamedInstanceReceipt (Entity _ e) -> receiptName e
        NamedInstanceProcessPeriod (Entity _ e) -> processPeriodName e
    
data NamedInstanceFilterType = NamedInstanceNameFilter (SqlExpr (Database.Esqueleto.Value (Text)) -> SqlExpr (Database.Esqueleto.Value Bool))
lookupNamedInstance :: forall (m :: * -> *). (MonadIO m) =>
    NamedInstanceId -> SqlPersistT m (Maybe NamedInstance)
lookupNamedInstance k = case k of
        NamedInstanceFileId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ NamedInstanceFile $ Entity key val
        NamedInstanceUserGroupId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ NamedInstanceUserGroup $ Entity key val
        NamedInstanceUserId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ NamedInstanceUser $ Entity key val
        NamedInstanceReceiptId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ NamedInstanceReceipt $ Entity key val
        NamedInstanceProcessPeriodId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ NamedInstanceProcessPeriod $ Entity key val

    
selectNamed :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[NamedInstanceFilterType]] -> SqlPersistT m [NamedInstance]
selectNamed filters = do
    result_File <- select $ from $ \e -> do
        let _ = e ^. FileId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. FileName
    
            ) exprs
    
        return e
    result_UserGroup <- select $ from $ \e -> do
        let _ = e ^. UserGroupId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. UserGroupName
    
            ) exprs
    
        return e
    result_User <- select $ from $ \e -> do
        let _ = e ^. UserId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. UserName
    
            ) exprs
    
        return e
    result_Receipt <- select $ from $ \e -> do
        let _ = e ^. ReceiptId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. ReceiptName
    
            ) exprs
    
        return e
    result_ProcessPeriod <- select $ from $ \e -> do
        let _ = e ^. ProcessPeriodId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. ProcessPeriodName
    
            ) exprs
    
        return e

    return $ concat [
        map NamedInstanceFile result_File
        , map NamedInstanceUserGroup result_UserGroup
        , map NamedInstanceUser result_User
        , map NamedInstanceReceipt result_Receipt
        , map NamedInstanceProcessPeriod result_ProcessPeriod

        ]
data NamedInstanceUpdateType = NamedInstanceUpdateName (SqlExpr (Database.Esqueleto.Value (Text)))
updateNamed :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[NamedInstanceFilterType]] -> [NamedInstanceUpdateType] -> SqlPersistT m ()
updateNamed filters updates = do
    update $ \e -> do
        let _ = e ^. FileId
        set e $ map (\u -> case u of
                    NamedInstanceUpdateName v -> FileName =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. FileName
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserGroupId
        set e $ map (\u -> case u of
                    NamedInstanceUpdateName v -> UserGroupName =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. UserGroupName
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserId
        set e $ map (\u -> case u of
                    NamedInstanceUpdateName v -> UserName =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. UserName
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. ReceiptId
        set e $ map (\u -> case u of
                    NamedInstanceUpdateName v -> ReceiptName =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. ReceiptName
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. ProcessPeriodId
        set e $ map (\u -> case u of
                    NamedInstanceUpdateName v -> ProcessPeriodName =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                NamedInstanceNameFilter op -> op $ e ^. ProcessPeriodName
    
            ) exprs
    
     
                

    return ()

class HasInsertInfo a where
    hasInsertInfoInsertionTime :: a -> UTCTime
    hasInsertInfoInsertedByUserId :: a -> Maybe UserId
data HasInsertInfoInstanceFieldName = HasInsertInfoInsertionTime    | HasInsertInfoInsertedByUserId 
instance HasInsertInfo File where
    hasInsertInfoInsertionTime = fileInsertionTime
    hasInsertInfoInsertedByUserId = fileInsertedByUserId
instance HasInsertInfo Receipt where
    hasInsertInfoInsertionTime = receiptInsertionTime
    hasInsertInfoInsertedByUserId = receiptInsertedByUserId
data HasInsertInfoInstance = HasInsertInfoInstanceFile (Entity File)
    | HasInsertInfoInstanceReceipt (Entity Receipt)


data HasInsertInfoInstanceId = HasInsertInfoInstanceFileId FileId
    | HasInsertInfoInstanceReceiptId ReceiptId
    deriving (Eq, Ord)

reflectHasInsertInfoInstanceId :: HasInsertInfoInstanceId -> (Text, Int64)
reflectHasInsertInfoInstanceId x = case x of
    HasInsertInfoInstanceFileId key -> ("File", fromSqlKey key)
    HasInsertInfoInstanceReceiptId key -> ("Receipt", fromSqlKey key)


instance HasInsertInfo HasInsertInfoInstance where
    hasInsertInfoInsertionTime x = case x of
        HasInsertInfoInstanceFile (Entity _ e) -> fileInsertionTime e
        HasInsertInfoInstanceReceipt (Entity _ e) -> receiptInsertionTime e
    
    hasInsertInfoInsertedByUserId x = case x of
        HasInsertInfoInstanceFile (Entity _ e) -> fileInsertedByUserId e
        HasInsertInfoInstanceReceipt (Entity _ e) -> receiptInsertedByUserId e
    
data HasInsertInfoInstanceFilterType = HasInsertInfoInstanceInsertionTimeFilter (SqlExpr (Database.Esqueleto.Value (UTCTime)) -> SqlExpr (Database.Esqueleto.Value Bool))    | HasInsertInfoInstanceInsertedByUserIdFilter (SqlExpr (Database.Esqueleto.Value (Maybe UserId)) -> SqlExpr (Database.Esqueleto.Value Bool))
lookupHasInsertInfoInstance :: forall (m :: * -> *). (MonadIO m) =>
    HasInsertInfoInstanceId -> SqlPersistT m (Maybe HasInsertInfoInstance)
lookupHasInsertInfoInstance k = case k of
        HasInsertInfoInstanceFileId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ HasInsertInfoInstanceFile $ Entity key val
        HasInsertInfoInstanceReceiptId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ HasInsertInfoInstanceReceipt $ Entity key val

    
selectHasInsertInfo :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[HasInsertInfoInstanceFilterType]] -> SqlPersistT m [HasInsertInfoInstance]
selectHasInsertInfo filters = do
    result_File <- select $ from $ \e -> do
        let _ = e ^. FileId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                HasInsertInfoInstanceInsertionTimeFilter op -> op $ e ^. FileInsertionTime
                HasInsertInfoInstanceInsertedByUserIdFilter op -> op $ e ^. FileInsertedByUserId
    
            ) exprs
    
        return e
    result_Receipt <- select $ from $ \e -> do
        let _ = e ^. ReceiptId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                HasInsertInfoInstanceInsertionTimeFilter op -> op $ e ^. ReceiptInsertionTime
                HasInsertInfoInstanceInsertedByUserIdFilter op -> op $ e ^. ReceiptInsertedByUserId
    
            ) exprs
    
        return e

    return $ concat [
        map HasInsertInfoInstanceFile result_File
        , map HasInsertInfoInstanceReceipt result_Receipt

        ]
data HasInsertInfoInstanceUpdateType = HasInsertInfoInstanceUpdateInsertionTime (SqlExpr (Database.Esqueleto.Value (UTCTime)))    | HasInsertInfoInstanceUpdateInsertedByUserId (SqlExpr (Database.Esqueleto.Value (Maybe UserId)))
updateHasInsertInfo :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[HasInsertInfoInstanceFilterType]] -> [HasInsertInfoInstanceUpdateType] -> SqlPersistT m ()
updateHasInsertInfo filters updates = do
    update $ \e -> do
        let _ = e ^. FileId
        set e $ map (\u -> case u of
                    HasInsertInfoInstanceUpdateInsertionTime v -> FileInsertionTime =. v
                    HasInsertInfoInstanceUpdateInsertedByUserId v -> FileInsertedByUserId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                HasInsertInfoInstanceInsertionTimeFilter op -> op $ e ^. FileInsertionTime
                HasInsertInfoInstanceInsertedByUserIdFilter op -> op $ e ^. FileInsertedByUserId
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. ReceiptId
        set e $ map (\u -> case u of
                    HasInsertInfoInstanceUpdateInsertionTime v -> ReceiptInsertionTime =. v
                    HasInsertInfoInstanceUpdateInsertedByUserId v -> ReceiptInsertedByUserId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                HasInsertInfoInstanceInsertionTimeFilter op -> op $ e ^. ReceiptInsertionTime
                HasInsertInfoInstanceInsertedByUserIdFilter op -> op $ e ^. ReceiptInsertedByUserId
    
            ) exprs
    
     
                

    return ()

class Restricted a where
instance Restricted File where
instance Restricted UserGroup where
instance Restricted User where
instance Restricted Receipt where
instance Restricted ProcessPeriod where
data RestrictedInstance = RestrictedInstanceFile (Entity File)
    | RestrictedInstanceUserGroup (Entity UserGroup)
    | RestrictedInstanceUser (Entity User)
    | RestrictedInstanceReceipt (Entity Receipt)
    | RestrictedInstanceProcessPeriod (Entity ProcessPeriod)


data RestrictedInstanceId = RestrictedInstanceFileId FileId
    | RestrictedInstanceUserGroupId UserGroupId
    | RestrictedInstanceUserId UserId
    | RestrictedInstanceReceiptId ReceiptId
    | RestrictedInstanceProcessPeriodId ProcessPeriodId
    deriving (Eq, Ord)

reflectRestrictedInstanceId :: RestrictedInstanceId -> (Text, Int64)
reflectRestrictedInstanceId x = case x of
    RestrictedInstanceFileId key -> ("File", fromSqlKey key)
    RestrictedInstanceUserGroupId key -> ("UserGroup", fromSqlKey key)
    RestrictedInstanceUserId key -> ("User", fromSqlKey key)
    RestrictedInstanceReceiptId key -> ("Receipt", fromSqlKey key)
    RestrictedInstanceProcessPeriodId key -> ("ProcessPeriod", fromSqlKey key)


instance Restricted RestrictedInstance where
lookupRestrictedInstance :: forall (m :: * -> *). (MonadIO m) =>
    RestrictedInstanceId -> SqlPersistT m (Maybe RestrictedInstance)
lookupRestrictedInstance k = case k of
        RestrictedInstanceFileId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ RestrictedInstanceFile $ Entity key val
        RestrictedInstanceUserGroupId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ RestrictedInstanceUserGroup $ Entity key val
        RestrictedInstanceUserId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ RestrictedInstanceUser $ Entity key val
        RestrictedInstanceReceiptId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ RestrictedInstanceReceipt $ Entity key val
        RestrictedInstanceProcessPeriodId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ RestrictedInstanceProcessPeriod $ Entity key val

    
selectRestricted :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
     SqlPersistT m [RestrictedInstance]
selectRestricted  = do
    result_File <- select $ from $ \e -> do
        let _ = e ^. FileId
    
        return e
    result_UserGroup <- select $ from $ \e -> do
        let _ = e ^. UserGroupId
    
        return e
    result_User <- select $ from $ \e -> do
        let _ = e ^. UserId
    
        return e
    result_Receipt <- select $ from $ \e -> do
        let _ = e ^. ReceiptId
    
        return e
    result_ProcessPeriod <- select $ from $ \e -> do
        let _ = e ^. ProcessPeriodId
    
        return e

    return $ concat [
        map RestrictedInstanceFile result_File
        , map RestrictedInstanceUserGroup result_UserGroup
        , map RestrictedInstanceUser result_User
        , map RestrictedInstanceReceipt result_Receipt
        , map RestrictedInstanceProcessPeriod result_ProcessPeriod

        ]
class Versioned a where
    versionedActiveId :: a -> Maybe VersionedInstanceId
    versionedActiveStartTime :: a -> Maybe UTCTime
    versionedActiveEndTime :: a -> Maybe UTCTime
data VersionedInstanceFieldName = VersionedActiveId    | VersionedActiveStartTime    | VersionedActiveEndTime 
instance Versioned File where
    versionedActiveId = (fmap VersionedInstanceFileId) . fileActiveId
    versionedActiveStartTime = fileActiveStartTime
    versionedActiveEndTime = fileActiveEndTime
instance Versioned UserGroup where
    versionedActiveId = (fmap VersionedInstanceUserGroupId) . userGroupActiveId
    versionedActiveStartTime = userGroupActiveStartTime
    versionedActiveEndTime = userGroupActiveEndTime
instance Versioned User where
    versionedActiveId = (fmap VersionedInstanceUserId) . userActiveId
    versionedActiveStartTime = userActiveStartTime
    versionedActiveEndTime = userActiveEndTime
instance Versioned Receipt where
    versionedActiveId = (fmap VersionedInstanceReceiptId) . receiptActiveId
    versionedActiveStartTime = receiptActiveStartTime
    versionedActiveEndTime = receiptActiveEndTime
data VersionedInstance = VersionedInstanceFile (Entity File)
    | VersionedInstanceUserGroup (Entity UserGroup)
    | VersionedInstanceUser (Entity User)
    | VersionedInstanceReceipt (Entity Receipt)


data VersionedInstanceId = VersionedInstanceFileId FileId
    | VersionedInstanceUserGroupId UserGroupId
    | VersionedInstanceUserId UserId
    | VersionedInstanceReceiptId ReceiptId
    deriving (Eq, Ord)

reflectVersionedInstanceId :: VersionedInstanceId -> (Text, Int64)
reflectVersionedInstanceId x = case x of
    VersionedInstanceFileId key -> ("File", fromSqlKey key)
    VersionedInstanceUserGroupId key -> ("UserGroup", fromSqlKey key)
    VersionedInstanceUserId key -> ("User", fromSqlKey key)
    VersionedInstanceReceiptId key -> ("Receipt", fromSqlKey key)


instance Versioned VersionedInstance where
    versionedActiveId x = case x of
        VersionedInstanceFile (Entity _ e) -> (fmap VersionedInstanceFileId) $ fileActiveId e
        VersionedInstanceUserGroup (Entity _ e) -> (fmap VersionedInstanceUserGroupId) $ userGroupActiveId e
        VersionedInstanceUser (Entity _ e) -> (fmap VersionedInstanceUserId) $ userActiveId e
        VersionedInstanceReceipt (Entity _ e) -> (fmap VersionedInstanceReceiptId) $ receiptActiveId e
    
    versionedActiveStartTime x = case x of
        VersionedInstanceFile (Entity _ e) -> fileActiveStartTime e
        VersionedInstanceUserGroup (Entity _ e) -> userGroupActiveStartTime e
        VersionedInstanceUser (Entity _ e) -> userActiveStartTime e
        VersionedInstanceReceipt (Entity _ e) -> receiptActiveStartTime e
    
    versionedActiveEndTime x = case x of
        VersionedInstanceFile (Entity _ e) -> fileActiveEndTime e
        VersionedInstanceUserGroup (Entity _ e) -> userGroupActiveEndTime e
        VersionedInstanceUser (Entity _ e) -> userActiveEndTime e
        VersionedInstanceReceipt (Entity _ e) -> receiptActiveEndTime e
    
data VersionedInstanceFilterType = VersionedInstanceActiveStartTimeFilter (SqlExpr (Database.Esqueleto.Value (Maybe UTCTime)) -> SqlExpr (Database.Esqueleto.Value Bool))    | VersionedInstanceActiveEndTimeFilter (SqlExpr (Database.Esqueleto.Value (Maybe UTCTime)) -> SqlExpr (Database.Esqueleto.Value Bool))
lookupVersionedInstance :: forall (m :: * -> *). (MonadIO m) =>
    VersionedInstanceId -> SqlPersistT m (Maybe VersionedInstance)
lookupVersionedInstance k = case k of
        VersionedInstanceFileId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ VersionedInstanceFile $ Entity key val
        VersionedInstanceUserGroupId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ VersionedInstanceUserGroup $ Entity key val
        VersionedInstanceUserId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ VersionedInstanceUser $ Entity key val
        VersionedInstanceReceiptId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ VersionedInstanceReceipt $ Entity key val

    
selectVersioned :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[VersionedInstanceFilterType]] -> SqlPersistT m [VersionedInstance]
selectVersioned filters = do
    result_File <- select $ from $ \e -> do
        let _ = e ^. FileId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. FileActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. FileActiveEndTime
    
            ) exprs
    
        return e
    result_UserGroup <- select $ from $ \e -> do
        let _ = e ^. UserGroupId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. UserGroupActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. UserGroupActiveEndTime
    
            ) exprs
    
        return e
    result_User <- select $ from $ \e -> do
        let _ = e ^. UserId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. UserActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. UserActiveEndTime
    
            ) exprs
    
        return e
    result_Receipt <- select $ from $ \e -> do
        let _ = e ^. ReceiptId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. ReceiptActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. ReceiptActiveEndTime
    
            ) exprs
    
        return e

    return $ concat [
        map VersionedInstanceFile result_File
        , map VersionedInstanceUserGroup result_UserGroup
        , map VersionedInstanceUser result_User
        , map VersionedInstanceReceipt result_Receipt

        ]
data VersionedInstanceUpdateType = VersionedInstanceUpdateActiveStartTime (SqlExpr (Database.Esqueleto.Value (Maybe UTCTime)))    | VersionedInstanceUpdateActiveEndTime (SqlExpr (Database.Esqueleto.Value (Maybe UTCTime)))
updateVersioned :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[VersionedInstanceFilterType]] -> [VersionedInstanceUpdateType] -> SqlPersistT m ()
updateVersioned filters updates = do
    update $ \e -> do
        let _ = e ^. FileId
        set e $ map (\u -> case u of
                    VersionedInstanceUpdateActiveStartTime v -> FileActiveStartTime =. v
                    VersionedInstanceUpdateActiveEndTime v -> FileActiveEndTime =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. FileActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. FileActiveEndTime
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserGroupId
        set e $ map (\u -> case u of
                    VersionedInstanceUpdateActiveStartTime v -> UserGroupActiveStartTime =. v
                    VersionedInstanceUpdateActiveEndTime v -> UserGroupActiveEndTime =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. UserGroupActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. UserGroupActiveEndTime
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserId
        set e $ map (\u -> case u of
                    VersionedInstanceUpdateActiveStartTime v -> UserActiveStartTime =. v
                    VersionedInstanceUpdateActiveEndTime v -> UserActiveEndTime =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. UserActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. UserActiveEndTime
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. ReceiptId
        set e $ map (\u -> case u of
                    VersionedInstanceUpdateActiveStartTime v -> ReceiptActiveStartTime =. v
                    VersionedInstanceUpdateActiveEndTime v -> ReceiptActiveEndTime =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                VersionedInstanceActiveStartTimeFilter op -> op $ e ^. ReceiptActiveStartTime
                VersionedInstanceActiveEndTimeFilter op -> op $ e ^. ReceiptActiveEndTime
    
            ) exprs
    
     
                

    return ()

class Deletable a where
    deletableDeletedVersionId :: a -> Maybe VersionId
data DeletableInstanceFieldName = DeletableDeletedVersionId 
instance Deletable File where
    deletableDeletedVersionId = fileDeletedVersionId
instance Deletable UserGroupContent where
    deletableDeletedVersionId = userGroupContentDeletedVersionId
instance Deletable UserGroup where
    deletableDeletedVersionId = userGroupDeletedVersionId
instance Deletable UserGroupItem where
    deletableDeletedVersionId = userGroupItemDeletedVersionId
instance Deletable User where
    deletableDeletedVersionId = userDeletedVersionId
instance Deletable Receipt where
    deletableDeletedVersionId = receiptDeletedVersionId
data DeletableInstance = DeletableInstanceFile (Entity File)
    | DeletableInstanceUserGroupContent (Entity UserGroupContent)
    | DeletableInstanceUserGroup (Entity UserGroup)
    | DeletableInstanceUserGroupItem (Entity UserGroupItem)
    | DeletableInstanceUser (Entity User)
    | DeletableInstanceReceipt (Entity Receipt)


data DeletableInstanceId = DeletableInstanceFileId FileId
    | DeletableInstanceUserGroupContentId UserGroupContentId
    | DeletableInstanceUserGroupId UserGroupId
    | DeletableInstanceUserGroupItemId UserGroupItemId
    | DeletableInstanceUserId UserId
    | DeletableInstanceReceiptId ReceiptId
    deriving (Eq, Ord)

reflectDeletableInstanceId :: DeletableInstanceId -> (Text, Int64)
reflectDeletableInstanceId x = case x of
    DeletableInstanceFileId key -> ("File", fromSqlKey key)
    DeletableInstanceUserGroupContentId key -> ("UserGroupContent", fromSqlKey key)
    DeletableInstanceUserGroupId key -> ("UserGroup", fromSqlKey key)
    DeletableInstanceUserGroupItemId key -> ("UserGroupItem", fromSqlKey key)
    DeletableInstanceUserId key -> ("User", fromSqlKey key)
    DeletableInstanceReceiptId key -> ("Receipt", fromSqlKey key)


instance Deletable DeletableInstance where
    deletableDeletedVersionId x = case x of
        DeletableInstanceFile (Entity _ e) -> fileDeletedVersionId e
        DeletableInstanceUserGroupContent (Entity _ e) -> userGroupContentDeletedVersionId e
        DeletableInstanceUserGroup (Entity _ e) -> userGroupDeletedVersionId e
        DeletableInstanceUserGroupItem (Entity _ e) -> userGroupItemDeletedVersionId e
        DeletableInstanceUser (Entity _ e) -> userDeletedVersionId e
        DeletableInstanceReceipt (Entity _ e) -> receiptDeletedVersionId e
    
data DeletableInstanceFilterType = DeletableInstanceDeletedVersionIdFilter (SqlExpr (Database.Esqueleto.Value (Maybe VersionId)) -> SqlExpr (Database.Esqueleto.Value Bool))
lookupDeletableInstance :: forall (m :: * -> *). (MonadIO m) =>
    DeletableInstanceId -> SqlPersistT m (Maybe DeletableInstance)
lookupDeletableInstance k = case k of
        DeletableInstanceFileId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ DeletableInstanceFile $ Entity key val
        DeletableInstanceUserGroupContentId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ DeletableInstanceUserGroupContent $ Entity key val
        DeletableInstanceUserGroupId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ DeletableInstanceUserGroup $ Entity key val
        DeletableInstanceUserGroupItemId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ DeletableInstanceUserGroupItem $ Entity key val
        DeletableInstanceUserId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ DeletableInstanceUser $ Entity key val
        DeletableInstanceReceiptId key -> runMaybeT $ do
            val <- MaybeT $ get key
            return $ DeletableInstanceReceipt $ Entity key val

    
selectDeletable :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[DeletableInstanceFilterType]] -> SqlPersistT m [DeletableInstance]
selectDeletable filters = do
    result_File <- select $ from $ \e -> do
        let _ = e ^. FileId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. FileDeletedVersionId
    
            ) exprs
    
        return e
    result_UserGroupContent <- select $ from $ \e -> do
        let _ = e ^. UserGroupContentId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserGroupContentDeletedVersionId
    
            ) exprs
    
        return e
    result_UserGroup <- select $ from $ \e -> do
        let _ = e ^. UserGroupId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserGroupDeletedVersionId
    
            ) exprs
    
        return e
    result_UserGroupItem <- select $ from $ \e -> do
        let _ = e ^. UserGroupItemId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserGroupItemDeletedVersionId
    
            ) exprs
    
        return e
    result_User <- select $ from $ \e -> do
        let _ = e ^. UserId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserDeletedVersionId
    
            ) exprs
    
        return e
    result_Receipt <- select $ from $ \e -> do
        let _ = e ^. ReceiptId
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. ReceiptDeletedVersionId
    
            ) exprs
    
        return e

    return $ concat [
        map DeletableInstanceFile result_File
        , map DeletableInstanceUserGroupContent result_UserGroupContent
        , map DeletableInstanceUserGroup result_UserGroup
        , map DeletableInstanceUserGroupItem result_UserGroupItem
        , map DeletableInstanceUser result_User
        , map DeletableInstanceReceipt result_Receipt

        ]
data DeletableInstanceUpdateType = DeletableInstanceUpdateDeletedVersionId (SqlExpr (Database.Esqueleto.Value (Maybe VersionId)))
updateDeletable :: forall (m :: * -> *). 
    (MonadLogger m, MonadIO m, MonadThrow m, MonadBaseControl IO m) => 
    [[DeletableInstanceFilterType]] -> [DeletableInstanceUpdateType] -> SqlPersistT m ()
updateDeletable filters updates = do
    update $ \e -> do
        let _ = e ^. FileId
        set e $ map (\u -> case u of
                    DeletableInstanceUpdateDeletedVersionId v -> FileDeletedVersionId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. FileDeletedVersionId
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserGroupContentId
        set e $ map (\u -> case u of
                    DeletableInstanceUpdateDeletedVersionId v -> UserGroupContentDeletedVersionId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserGroupContentDeletedVersionId
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserGroupId
        set e $ map (\u -> case u of
                    DeletableInstanceUpdateDeletedVersionId v -> UserGroupDeletedVersionId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserGroupDeletedVersionId
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserGroupItemId
        set e $ map (\u -> case u of
                    DeletableInstanceUpdateDeletedVersionId v -> UserGroupItemDeletedVersionId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserGroupItemDeletedVersionId
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. UserId
        set e $ map (\u -> case u of
                    DeletableInstanceUpdateDeletedVersionId v -> UserDeletedVersionId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. UserDeletedVersionId
    
            ) exprs
    
     
                
    update $ \e -> do
        let _ = e ^. ReceiptId
        set e $ map (\u -> case u of
                    DeletableInstanceUpdateDeletedVersionId v -> ReceiptDeletedVersionId =. v
    
            ) updates
        forM_ filters $ \exprs -> 
            when (not . null $ exprs) $ where_ $ foldl1 (||.) $ map (\expr -> case expr of 
                DeletableInstanceDeletedVersionIdFilter op -> op $ e ^. ReceiptDeletedVersionId
    
            ) exprs
    
     
                

    return ()

userGroupContentContentId :: UserGroupContent -> Maybe (RestrictedInstanceId)
userGroupContentContentId e = listToMaybe $ catMaybes [
        userGroupContentFileContentId e >>= (return . RestrictedInstanceFileId)
        , userGroupContentUserGroupContentId e >>= (return . RestrictedInstanceUserGroupId)
        , userGroupContentUserContentId e >>= (return . RestrictedInstanceUserId)
        , userGroupContentReceiptContentId e >>= (return . RestrictedInstanceReceiptId)
        , userGroupContentProcessPeriodContentId e >>= (return . RestrictedInstanceProcessPeriodId)

    ]

class UserGroupContentContentIdField e where
    userGroupContentContentIdField :: SqlExpr (Database.Esqueleto.Value (Maybe (Key e))) -> EntityField UserGroupContent (Maybe (Key e)) 

instance UserGroupContentContentIdField ProcessPeriod where
    userGroupContentContentIdField _ = UserGroupContentProcessPeriodContentId
instance UserGroupContentContentIdField Receipt where
    userGroupContentContentIdField _ = UserGroupContentReceiptContentId
instance UserGroupContentContentIdField User where
    userGroupContentContentIdField _ = UserGroupContentUserContentId
instance UserGroupContentContentIdField UserGroup where
    userGroupContentContentIdField _ = UserGroupContentUserGroupContentId
instance UserGroupContentContentIdField File where
    userGroupContentContentIdField _ = UserGroupContentFileContentId
    

userGroupContentContentIdExprFromString :: Text -> SqlExpr (Entity UserGroupContent) -> Text -> Maybe Text -> Maybe (SqlExpr (E.Value Bool))
userGroupContentContentIdExprFromString "ProcessPeriod" e op vt = case vt of 
    Just vt' -> PP.fromPathPiece vt' >>= \v -> Just $ defaultFilterOp False op (e ^. UserGroupContentProcessPeriodContentId) (val v)
    Nothing -> Just $ defaultFilterOp False op (e ^. UserGroupContentProcessPeriodContentId) nothing
   
userGroupContentContentIdExprFromString "Receipt" e op vt = case vt of 
    Just vt' -> PP.fromPathPiece vt' >>= \v -> Just $ defaultFilterOp False op (e ^. UserGroupContentReceiptContentId) (val v)
    Nothing -> Just $ defaultFilterOp False op (e ^. UserGroupContentReceiptContentId) nothing
   
userGroupContentContentIdExprFromString "User" e op vt = case vt of 
    Just vt' -> PP.fromPathPiece vt' >>= \v -> Just $ defaultFilterOp False op (e ^. UserGroupContentUserContentId) (val v)
    Nothing -> Just $ defaultFilterOp False op (e ^. UserGroupContentUserContentId) nothing
   
userGroupContentContentIdExprFromString "UserGroup" e op vt = case vt of 
    Just vt' -> PP.fromPathPiece vt' >>= \v -> Just $ defaultFilterOp False op (e ^. UserGroupContentUserGroupContentId) (val v)
    Nothing -> Just $ defaultFilterOp False op (e ^. UserGroupContentUserGroupContentId) nothing
   
userGroupContentContentIdExprFromString "File" e op vt = case vt of 
    Just vt' -> PP.fromPathPiece vt' >>= \v -> Just $ defaultFilterOp False op (e ^. UserGroupContentFileContentId) (val v)
    Nothing -> Just $ defaultFilterOp False op (e ^. UserGroupContentFileContentId) nothing
   

userGroupContentContentIdExprFromString _ _ _ _ = Nothing

userGroupContentContentIdExpr2FromString :: Text -> SqlExpr (Entity UserGroupContent) -> Text -> SqlExpr (Entity UserGroupContent) -> Maybe (SqlExpr (E.Value Bool))
userGroupContentContentIdExpr2FromString "ProcessPeriod" e op e2 = Just $ defaultFilterOp False op (e ^. UserGroupContentProcessPeriodContentId) (e2 ^. UserGroupContentProcessPeriodContentId)
userGroupContentContentIdExpr2FromString "Receipt" e op e2 = Just $ defaultFilterOp False op (e ^. UserGroupContentReceiptContentId) (e2 ^. UserGroupContentReceiptContentId)
userGroupContentContentIdExpr2FromString "User" e op e2 = Just $ defaultFilterOp False op (e ^. UserGroupContentUserContentId) (e2 ^. UserGroupContentUserContentId)
userGroupContentContentIdExpr2FromString "UserGroup" e op e2 = Just $ defaultFilterOp False op (e ^. UserGroupContentUserGroupContentId) (e2 ^. UserGroupContentUserGroupContentId)
userGroupContentContentIdExpr2FromString "File" e op e2 = Just $ defaultFilterOp False op (e ^. UserGroupContentFileContentId) (e2 ^. UserGroupContentFileContentId)

userGroupContentContentIdExpr2FromString _ _ _ _ = Nothing


instance ToJSON Day where
    toJSON = toJSON . show

instance FromJSON Day where
    parseJSON x = do
        s <- parseJSON x
        case reads s of
            (d, _):_ -> return d
            [] -> mzero 

instance ToJSON TimeOfDay where
    toJSON = toJSON . show

instance FromJSON TimeOfDay where
    parseJSON x = do
        s <- parseJSON x
        case reads s of
            (d, _):_ -> return d
            [] -> mzero

instance ToJSON Checkmark where
    toJSON Active   = A.String "Active"
    toJSON Inactive = A.String "Inactive"            

instance FromJSON Checkmark where
    parseJSON (A.String "Active") = return Active
    parseJSON (A.String "Inactive") = return Inactive    
    parseJSON _ = mzero   
