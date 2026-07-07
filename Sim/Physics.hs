{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}

module Sim.Physics
    ( simulate
    , SimulationResult(..)
    , getEnergy
    , getConvergence
    ) where

import Prelude
import Kernel.Core
import Kernel.Geodesic
import Kernel.Error

data SimulationResult = SimulationResult
    { trajectory :: [Agent]
    , finalEnergy :: Double
    , convergenceRate :: Double
    , constraintViolations :: Int
    } deriving (Show)

simulate :: Agent -> Double -> Int -> Double -> Either KernelError SimulationResult
simulate agent0 callFreq nSteps dt = do
    traj <- simulateSteps nSteps agent0 (Scalar32 (round (callFreq * 65536))) 
                                       (Scalar32 (round (dt * 65536)))
    let finalE = trajectoryEnergy (last traj) (Scalar32 (round (callFreq * 65536)))
    let (mean, stdDev, _, _) = trajectoryStats traj
    return $ SimulationResult
        { trajectory = traj
        , finalEnergy = finalE
        , convergenceRate = stdDev
        , constraintViolations = 0
        }

getEnergy :: Agent -> Double -> Double
getEnergy agent callFreq = 
    trajectoryEnergy agent (Scalar32 (round (callFreq * 65536)))

getConvergence :: [Agent] -> Double
getConvergence [] = 0
getConvergence [_] = 0
getConvergence agents =
    let (_, stdDev, _, _) = trajectoryStats agents
    in stdDev
