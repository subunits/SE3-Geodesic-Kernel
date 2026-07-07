{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}

module Sim.Playground
    ( simulateAgent
    , simulateAgents
    , SimConfig(..)
    , defaultConfig
    , toJSON
    ) where

import Prelude
import Kernel.Core
import Data.List (foldl')

data SimConfig = SimConfig
    { cfgSteps :: Int
    , cfgDt :: Double
    , cfgLangevinNoise :: Double
    , cfgProjectionInterval :: Int
    } deriving (Show)

defaultConfig :: SimConfig
defaultConfig = SimConfig
    { cfgSteps = 100
    , cfgDt = 0.01
    , cfgLangevinNoise = 0.01
    , cfgProjectionInterval = 5
    }

simulateAgent :: SimConfig -> Agent -> Double -> [Agent]
simulateAgent cfg agent0 callFreq = take (cfgSteps cfg) (iterate step agent0)
  where
    step ag = ag  -- Stub: would integrate geodesic equation

simulateAgents :: SimConfig -> [Agent] -> Double -> [[Agent]]
simulateAgents cfg agents callFreq = map (simulateAgent cfg agent0 callFreq) agents
  where
    agent0 = head agents

toJSON :: Agent -> String
toJSON Agent{..} = 
    "{\"pos\":{},\"vel\":0,\"resonance\":0,\"mass\":0}"
