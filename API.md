# Complete API Reference

## Module: Kernel.Core

### Types

```haskell
newtype Scalar32 = Scalar32 Int32
newtype Scalar16 = Scalar16 Int16

data Quaternion = Quaternion 
    { qW :: Scalar32, qX :: Scalar32, qY :: Scalar32, qZ :: Scalar32 }

data DualQuaternion = DualQuaternion
    { realPart :: Quaternion, dualPart :: Quaternion }

data Agent = Agent
    { agentPos :: DualQuaternion
    , agentVel :: Scalar32
    , agentResonance :: Scalar32
    , agentMass :: Scalar32
    }
```

### Functions

#### Conversions
- `toScalar32 :: Double -> Either String Scalar32`
- `fromScalar32 :: Scalar32 -> Double`
- `toScalar16 :: Double -> Either String Scalar16`
- `fromScalar16 :: Scalar16 -> Double`

#### Arithmetic
- `scalarAdd :: Scalar32 -> Scalar32 -> Scalar32`
- `scalarSub :: Scalar32 -> Scalar32 -> Scalar32`
- `scalarMul :: Scalar32 -> Scalar32 -> Scalar32`
- `scalarDiv :: Scalar32 -> Scalar32 -> Scalar32`
- `scalarNegate :: Scalar32 -> Scalar32`
- `scalarAbs :: Scalar32 -> Scalar32`

#### Quaternion Operations
- `qNorm :: Quaternion -> Scalar32`
- `qDotProduct :: Quaternion -> Quaternion -> Scalar32`
- `qAdd :: Quaternion -> Quaternion -> Quaternion`
- `qMul :: Quaternion -> Quaternion -> Quaternion`
- `qConjugate :: Quaternion -> Quaternion`

## Module: Kernel.Geodesic

### Functions

- `geodesicStep :: Agent -> Scalar32 -> Scalar32 -> Either KernelError Agent`
- `simulateSteps :: Int -> Agent -> Scalar32 -> Scalar32 -> Either KernelError [Agent]`
- `convergenceMetric :: Agent -> Agent -> Double`
- `hasConverged :: [Agent] -> Double -> Bool`
- `trajectoryEnergy :: Agent -> Scalar32 -> Double`
- `trajectoryStats :: [Agent] -> (Double, Double, Double, Double)`

## Module: Sim.Playground

- `simulateAgent :: SimConfig -> Agent -> Double -> [Agent]`
- `simulateAgents :: SimConfig -> [Agent] -> Double -> [[Agent]]`

## Module: Sim.Physics

- `simulate :: Agent -> Double -> Int -> Double -> Either KernelError SimulationResult`
- `getEnergy :: Agent -> Double -> Double`
- `getConvergence :: [Agent] -> Double`
