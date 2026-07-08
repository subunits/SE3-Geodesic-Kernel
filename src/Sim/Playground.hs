
{-# LANGUAGE NoImplicitPrelude #-}

module Sim.Playground where

import Prelude
import Kernel.Core

data SimConfig = SimConfig {cfgSteps :: Int, cfgDt :: Double, cfgLangevinNoise :: Double, cfgProjectionInterval :: Int} deriving (Show)
defaultConfig = SimConfig {cfgSteps = 100, cfgDt = 0.01, cfgLangevinNoise = 0.01, cfgProjectionInterval = 5}

simulateAgent cfg agent0 _callFreq = replicate (cfgSteps cfg) agent0
simulateAgents cfg agents callFreq = map (\a -> simulateAgent cfg a callFreq) agents
toJSON _ = "{}"
