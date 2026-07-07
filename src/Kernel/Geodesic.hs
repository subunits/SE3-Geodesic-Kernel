{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}

{-|
Module      : Kernel.Geodesic
Description : Geodesic integration and trajectory computation
Stability   : experimental

Implements numerical integration of geodesic equations on SE(3) with
adaptive timesteps and convergence detection.
-}

module Kernel.Geodesic
    ( -- * Integration
      geodesicStep
    , geodesicStepAdaptive
    , simulateSteps
    
    -- * Convergence
    , convergenceMetric
    , hasConverged
    
    -- * Analysis
    , trajectoryEnergy
    , trajectoryStats
    ) where

import Prelude hiding ((.), id)
import Kernel.Core
import Kernel.Manifold
import Kernel.FixedPoint
import Kernel.Error
import Data.List (foldl')

-- ====================================================
-- SINGLE STEP INTEGRATION
-- ====================================================

{-|
Perform a single geodesic integration step with fixed timestep.

Steps:
1. Compute metric dissonance: ε = resonance - callFrequency
2. Update velocity: v' = v - (ε × v / mass) × dt
3. Move position: p' = p + v' × dt
4. Project back to manifold
-}
geodesicStep
    :: Agent                  -- ^ Current agent state
    -> Scalar32               -- ^ Call frequency (metric field)
    -> Scalar32               -- ^ Timestep dt
    -> Either KernelError Agent
geodesicStep agent@Agent{..} callFreq dt = do
    -- Compute dissonance
    let dissonance = scalarSub agentResonance callFreq
    
    -- Update velocity using parallel transport
    vNew <- parallelTransportWithMass agentMass dissonance agentVel dt
    
    -- Move along geodesic
    let displacement = scalarMul vNew dt
    let pNew = stepGeodesicManually agentPos displacement
    
    -- Project back to manifold
    pProjected <- projectSE3Safe pNew
    
    return $ Agent
        { agentPos = pProjected
        , agentVel = vNew
        , agentResonance = agentResonance  -- Resonance doesn't change
        , agentMass = agentMass
        }

-- ====================================================
-- ADAPTIVE TIMESTEP INTEGRATION
-- ====================================================

{-|
Geodesic step with adaptive timestep based on constraint violation.

If manifold constraints are violated, halves the timestep and retries.
-}
geodesicStepAdaptive
    :: Agent
    -> Scalar32
    -> Scalar32  -- ^ Initial timestep
    -> Scalar32  -- ^ Minimum timestep
    -> Either KernelError (Agent, Scalar32)  -- ^ Returns (newAgent, usedTimestep)
geodesicStepAdaptive agent callFreq dt dtMin = 
    stepWithAdaptation agent callFreq dt dtMin
  where
    stepWithAdaptation ag cf curDt minDt
        | curDt < minDt = Left $ ConvergenceFailed "Timestep too small"
        | otherwise = do
            ag' <- geodesicStep ag cf curDt
            
            -- Check manifold constraint
            case checkManifoldConstraint (realPart (agentPos ag')) of
                Left _ -> 
                    -- Constraint violated, try smaller timestep
                    stepWithAdaptation ag cf (scalarDiv curDt (Scalar32 2)) minDt
                Right _ -> 
                    -- Success
                    return (ag', curDt)

-- ====================================================
-- MULTI-STEP SIMULATION
-- ====================================================

{-|
Simulate multiple steps, collecting trajectory.
-}
simulateSteps
    :: Int                    -- ^ Number of steps
    -> Agent                  -- ^ Initial state
    -> Scalar32               -- ^ Call frequency
    -> Scalar32               -- ^ Timestep
    -> Either KernelError [Agent]
simulateSteps n agent0 callFreq dt = 
    foldl' step (Right [agent0]) [1..n]
  where
    step (Left err) _ = Left err
    step (Right traj) _ = do
        next <- geodesicStep (last traj) callFreq dt
        return (traj ++ [next])

-- ====================================================
-- CONVERGENCE ANALYSIS
-- ====================================================

{-|
Compute convergence metric: change in velocity magnitude.

Close to zero means the agent is approaching a fixed point.
-}
convergenceMetric :: Agent -> Agent -> Double
convergenceMetric ag1 ag2 =
    let v1 = scalarToDouble (agentVel ag1)
        v2 = scalarToDouble (agentVel ag2)
    in abs (v2 - v1)

{-|
Check if trajectory has converged (velocity stable).
-}
hasConverged
    :: [Agent]        -- ^ Recent trajectory
    -> Double         -- ^ Tolerance
    -> Bool
hasConverged [] _ = False
hasConverged [_] _ = False
hasConverged traj tol =
    let diffs = zipWith convergenceMetric traj (tail traj)
        avgDiff = sum diffs / fromIntegral (length diffs)
    in avgDiff < tol

-- ====================================================
-- TRAJECTORY ANALYSIS
-- ====================================================

{-|
Compute kinetic + potential energy of trajectory.

E = (1/2) * mass * ||v||² + potential(dissonance)
-}
trajectoryEnergy
    :: Agent
    -> Scalar32  -- ^ Call frequency
    -> Double
trajectoryEnergy Agent{..} callFreq =
    let vDouble = scalarToDouble agentVel
        mDouble = scalarToDouble agentMass
        dissonanceDouble = scalarToDouble (scalarSub agentResonance callFreq)
    in 0.5 * mDouble * vDouble * vDouble + 
       0.5 * dissonanceDouble * dissonanceDouble

{-|
Compute statistics over trajectory: (mean, stdDev, minVal, maxVal).
-}
trajectoryStats :: [Agent] -> (Double, Double, Double, Double)
trajectoryStats [] = (0, 0, 0, 0)
trajectoryStats agents =
    let vels = map (scalarToDouble . agentVel) agents
        n = fromIntegral (length vels)
        mean = sum vels / n
        variance = sum [(v - mean)^2 | v <- vels] / n
        stdDev = sqrt variance
        minVal = minimum vels
        maxVal = maximum vels
    in (mean, stdDev, minVal, maxVal)

-- ====================================================
-- HELPER FUNCTIONS (Internal)
-- ====================================================

stepGeodesicManually :: DualQuaternion -> Scalar32 -> DualQuaternion
stepGeodesicManually (DualQuaternion r d) disp =
    let r' = quarterionAddScalar r disp
        d' = quarterionAddScalar d disp
    in DualQuaternion r' d'

quarterionAddScalar :: Quaternion -> Scalar32 -> Quaternion
quarterionAddScalar (Quaternion w x y z) s =
    Quaternion (scalarAdd w s) (scalarAdd x s) (scalarAdd y s) (scalarAdd z s)

parallelTransportWithMass
    :: Scalar32 -> Scalar32 -> Scalar32 -> Scalar32
    -> Either KernelError Scalar32
parallelTransportWithMass mass diss vel dt =
    let force = scalarMul (scalarNegate diss) vel
        massSafe = if vel == Scalar32 0 then Scalar32 1 else mass
        accel = scalarDiv force massSafe
        dv = scalarMul accel dt
    in return $ scalarAdd vel dv
