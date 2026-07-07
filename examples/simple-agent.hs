{-|
Simple example: tracking a single agent through geodesic flow

This example demonstrates the basic usage of the SE(3) kernel
to simulate an agent navigating a Ricci-flat manifold.
-}

module Examples.SimpleAgent where

import Kernel.Core
import Kernel.Geodesic
import Kernel.Error
import Sim.Physics

example :: IO ()
example = do
    -- Define initial agent
    let agent = Agent
            { agentPos = DualQuaternion 
                (Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0))
                (Quaternion (Scalar32 0) (Scalar32 0) (Scalar32 0) (Scalar32 0))
            , agentVel = Scalar32 32768
            , agentResonance = Scalar32 52428
            , agentMass = Scalar32 65536
            }
    
    -- Run simulation
    let callFreq = Scalar32 58983
    case simulateSteps 50 agent callFreq (Scalar32 6553) of
        Left err -> putStrLn $ "Error: " ++ displayError err
        Right trajectory -> do
            putStrLn $ "Simulated " ++ show (length trajectory) ++ " steps"
            putStrLn $ "Final velocity: " ++ 
                       show (scalarToDouble (agentVel (last trajectory)))
