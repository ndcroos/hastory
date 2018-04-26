{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

module Hastory.Cli.Commands.ChangeDir where

import Import

import Hastory.Cli.Commands.Recent
import Hastory.Cli.OptParse.Types

change :: (MonadIO m, MonadReader Settings m) => Int -> m ()
change ix = do
    recentDirOpts <- getRecentDirOpts False
    liftIO $
        case recentDirOpts `atMay` ix of
            Nothing -> die "Invalid index choice."
            Just d -> putStrLn d