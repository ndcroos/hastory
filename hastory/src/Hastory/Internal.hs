{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TemplateHaskell #-}

module Hastory.Internal where

import Import

import qualified Data.Aeson as JSON
import qualified Data.ByteString.Lazy as LB
import qualified Data.ByteString.Lazy.Char8 as LB8

import Data.Time
import Data.Time.Clock
import Data.Time.Format

import Hastory.OptParse.Types
import Hastory.Types

hastoryDir :: MonadReader Settings m => m (Path Abs Dir)
hastoryDir = asks setCacheDir

histDir :: MonadReader Settings m => m (Path Abs Dir)
histDir = fmap (</> $(mkRelDir "command-history")) hastoryDir

histFileFor ::
       (MonadThrow m, MonadReader Settings m) => ZonedTime -> m (Path Abs File)
histFileFor zt = do
    hd <- histDir
    fn <- parseRelFile $ formatTime defaultTimeLocale "%F.log" zt
    pure $ hd </> fn

histFilesForLastDays ::
       (MonadThrow m, MonadReader Settings m)
    => Int
    -> ZonedTime
    -> m [Path Abs File]
histFilesForLastDays n zt =
    mapM histFileFor $
    flip map [0 .. n - 1] $ \d ->
        addZonedTime zt $ fromIntegral (-d * 24 * 60 * 60)

addZonedTime :: ZonedTime -> NominalDiffTime -> ZonedTime
addZonedTime zt ndt =
    let tz = zonedTimeZone zt
        utct = localTimeToUTC tz (zonedTimeToLocalTime zt)
        utct' = addUTCTime ndt utct
        lt' = utcToLocalTime tz utct'
    in ZonedTime {zonedTimeToLocalTime = lt', zonedTimeZone = tz}

getHistoryFrom :: (MonadIO m, MonadThrow m) => Path Abs File -> m [Entry]
getHistoryFrom hFile = do
    contents <- liftIO $ forgivingAbsence $ LB.readFile $ toFilePath hFile
    let encodedEntries = LB8.lines <$> contents
    let entries = catMaybes $ map JSON.decode $ fromMaybe [] encodedEntries
    pure entries

getLastNDaysOfHistory ::
       (MonadIO m,MonadThrow m, MonadReader Settings m) => Int -> m [Entry]
getLastNDaysOfHistory n = do
    zt <- liftIO getZonedTime
    hFiles <- histFilesForLastDays n zt
    concat <$> mapM getHistoryFrom hFiles

getHistory :: (MonadIO m, MonadThrow m, MonadReader Settings m) => m [Entry]
getHistory = do
    hd <- histDir
    fs <- snd <$> listDirRecur hd
    concat <$> mapM getHistoryFrom fs
