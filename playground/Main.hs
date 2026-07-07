{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Prelude
import Kernel.Core
import Kernel.Geodesic
import Kernel.Error
import Sim.Physics
import System.Environment
import Text.Printf

main :: IO ()
main = do
    putStrLn "=== SE(3) Geodesic Master Kernel Playground ==="
    putStrLn ""
    
    -- Create a test agent
    let agent = Agent
            { agentPos = DualQuaternion 
                (Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0))
                (Quaternion (Scalar32 0) (Scalar32 0) (Scalar32 0) (Scalar32 0))
            , agentVel = Scalar32 32768  -- 0.5
            , agentResonance = Scalar32 52428  -- 0.8
            , agentMass = Scalar32 65536  -- 1.0
            }
    
    putStrLn "Initial Agent State:"
    putStrLn $ "  Velocity: " ++ show (scalarToDouble (agentVel agent))
    putStrLn $ "  Resonance: " ++ show (scalarToDouble (agentResonance agent))
    putStrLn $ "  Mass: " ++ show (scalarToDouble (agentMass agent))
    putStrLn ""
    
    -- Run simulation
    putStrLn "Running 100-step simulation..."
    let callFreq = Scalar32 58983  -- 0.9
    let dt = Scalar32 6553  -- 0.1
    
    case simulateSteps 100 agent callFreq dt of
        Left err -> putStrLn $ "Error: " ++ displayError err
        Right trajectory -> do
            let finalAgent = last trajectory
            putStrLn "Simulation complete!"
            putStrLn ""
            putStrLn "Final Agent State:"
            putStrLn $ "  Velocity: " ++ show (scalarToDouble (agentVel finalAgent))
            putStrLn $ "  Resonance: " ++ show (scalarToDouble (agentResonance finalAgent))
            putStrLn ""
            
            let (mean, stdDev, minVal, maxVal) = trajectoryStats trajectory
            putStrLn "Statistics:"
            putStrLn $ "  Mean velocity: " ++ printf "%.6f" mean
            putStrLn $ "  Std deviation: " ++ printf "%.6f" stdDev
            putStrLn $ "  Min velocity: " ++ printf "%.6f" minVal
            putStrLn $ "  Max velocity: " ++ printf "%.6f" maxVal
            putStrLn ""
            
            if hasConverged trajectory 0.001
                then putStrLn "✓ System has converged"
                else putStrLn "✗ System has not converged"

scalarToDouble :: Scalar32 -> Double
scalarToDouble (Scalar32 x) = fromIntegral x / 65536
