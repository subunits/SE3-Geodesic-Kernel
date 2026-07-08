
{-# LANGUAGE NoImplicitPrelude #-}

module Sim.Physics where

import Prelude
import Kernel.Core
import Kernel.Geodesic
import Kernel.Error

data SimulationResult = SimulationResult {trajectory :: [Agent], finalEnergy :: Double, convergenceRate :: Double, constraintViolations :: Int} deriving (Show)

simulate agent0 callFreq nSteps dt = do
    let callFreqScalar = Scalar32 (round (callFreq * 65536))
    let dtScalar = Scalar32 (round (dt * 65536))
    traj <- simulateSteps nSteps agent0 callFreqScalar dtScalar
    let finalE = trajectoryEnergy (last traj) callFreqScalar
    let (_, stdDev, _, _) = trajectoryStats traj
    return $ SimulationResult {trajectory = traj, finalEnergy = finalE, convergenceRate = stdDev, constraintViolations = 0}

getEnergy agent callFreq = trajectoryEnergy agent (Scalar32 (round (callFreq * 65536)))
getConvergence [] = 0
getConvergence [_] = 0
getConvergence agents = let (_, stdDev, _, _) = trajectoryStats agents in stdDev
