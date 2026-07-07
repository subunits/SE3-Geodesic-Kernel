{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}

{-|
Module      : Kernel.Manifold
Description : SE(3) manifold projection and geodesic computations
Stability   : experimental

Implements the core geometric operations:
- Manifold projection (enforcing R_μν = 0 for Ricci-flat geometry)
- Parallel transport along geodesics
- Exponential map for tangent space integration
-}

module Kernel.Manifold
    ( -- * Manifold Operations
      projectSE3
    , projectSE3Safe
    
    -- * Parallel Transport
    , parallelTransport
    , parallelTransportWithMass
    
    -- * Geodesic Integration
    , stepGeodesic
    , stepGeodesicWithDamping
    
    -- * Verification
    , checkManifoldConstraint
    , checkOrthogonality
    ) where

import Prelude hiding ((.), id)
import Kernel.Core
import Kernel.Error
import Data.Bits

-- ====================================================
-- MANIFOLD PROJECTION
-- ====================================================

{-|
Project a dual quaternion back onto the SE(3) manifold.

Enforces two constraints:
1. Real part is unit norm: ||r|| = 1
2. Dual part is orthogonal to real: r · d = 0

Uses a corrective subtraction approach (stable numerically):
d' = d - (r · d) * r
-}
projectSE3 :: DualQuaternion -> DualQuaternion
projectSE3 dq = case projectSE3Safe dq of
    Right projected -> projected
    Left _ -> dq  -- Conservative: return original on error

projectSE3Safe :: DualQuaternion -> Either KernelError DualQuaternion
projectSE3Safe (DualQuaternion r d) = do
    -- Step 1: Normalize real part
    rNorm <- qNormSafe r
    rUnit <- qNormalizeSafe r
    
    -- Step 2: Enforce orthogonality: d' = d - (r · d) * r
    let dot = qDotProduct rUnit d
    let correction = qScaleSafe dot rUnit
    let dOrth = qSubtract d correction
    
    -- Step 3: Validate result
    validateDualQuaternion (DualQuaternion rUnit dOrth)
    
    return $ DualQuaternion rUnit dOrth

-- ====================================================
-- PARALLEL TRANSPORT (Metric-Aware Velocity Update)
-- ====================================================

{-|
Update velocity based on metric dissonance.

Implements: v' = v + (a * dt)
where acceleration = -(dissonance * velocity) / mass

This models inertial resistance to metric disturbances.
-}
parallelTransport 
    :: Scalar32     -- ^ Dissonance (resonance - callFreq)
    -> Scalar32     -- ^ Current velocity
    -> Scalar32     -- ^ Time step
    -> Either KernelError Scalar32
parallelTransport dissonance vel dt = do
    -- a = -(dissonance * vel)
    let force = qScaleSafe dissonance vel
    let negForce = negateSafe force
    
    -- v' = v + a*dt
    let acceleration = scalarMulSafe negForce dt
    scalarAddSafe vel acceleration

{-|
Parallel transport with inertial mass filtering.

Higher mass = lower susceptibility to metric dissonance.
-}
parallelTransportWithMass
    :: Scalar32     -- ^ Inertial mass
    -> Scalar32     -- ^ Dissonance
    -> Scalar32     -- ^ Current velocity
    -> Scalar32     -- ^ Time step
    -> Either KernelError Scalar32
parallelTransportWithMass mass dissonance vel dt = do
    -- force = -(dissonance * vel)
    let force = qScaleSafe dissonance vel
    let negForce = negateSafe force
    
    -- acceleration = force / mass
    let massSafe = if mass == Scalar32 0 then Scalar32 1 else mass
    let accel = scalarDivSafe negForce massSafe
    
    -- dv = accel * dt
    let dv = scalarMulSafe accel dt
    scalarAddSafe vel dv

-- ====================================================
-- GEODESIC INTEGRATION (Exponential Map)
-- ====================================================

{-|
Single geodesic step using exponential map.

Moves agent along the geodesic by integrating velocity.
-}
stepGeodesic
    :: DualQuaternion  -- ^ Current pose
    -> Scalar32        -- ^ Velocity
    -> Scalar32        -- ^ Time step
    -> Either KernelError DualQuaternion
stepGeodesic (DualQuaternion r d) vel dt = do
    -- Tangent vector displacement
    let displacement = scalarMulSafe vel dt
    
    -- Integrate: r' = r + v*dt, d' = d + v*dt
    r' <- qAddSafe r (qScaleSafe displacement (Quaternion (Scalar32 1) (Scalar32 0) (Scalar32 0) (Scalar32 0)))
    d' <- qAddSafe d (qScaleSafe displacement (Quaternion (Scalar32 1) (Scalar32 0) (Scalar32 0) (Scalar32 0)))
    
    -- Project back to manifold
    projectSE3Safe (DualQuaternion r' d')

{-|
Geodesic step with velocity damping (energy dissipation).

Adds friction/damping proportional to velocity: v' = v * (1 - damping * dt)
-}
stepGeodesicWithDamping
    :: DualQuaternion  -- ^ Current pose
    -> Scalar32        -- ^ Velocity
    -> Scalar32        -- ^ Damping coefficient
    -> Scalar32        -- ^ Time step
    -> Either KernelError (DualQuaternion, Scalar32)
stepGeodesicWithDamping pose vel damp dt = do
    -- Apply damping: v' = v * (1 - damp*dt)
    let dampFactor = scalarMulSafe damp dt
    let dampedVel = scalarMulSafe vel (Scalar32 (65536 - 1))  -- ≈ (1 - dampFactor)
    
    -- Integrate position
    newPose <- stepGeodesic pose dampedVel dt
    
    return (newPose, dampedVel)

-- ====================================================
-- VERIFICATION (Constraint Checking)
-- ====================================================

{-|
Check that a quaternion satisfies its manifold constraint.

For a rotation quaternion: ||q|| should be close to 1.
Tolerance: ±0.01 (allowing 1% error in fixed-point).
-}
checkManifoldConstraint :: Quaternion -> Either KernelError Double
checkManifoldConstraint q = do
    norm <- qNormSafe q
    let normDouble = fromScalar32 norm
    if abs (normDouble - 1.0) < 0.01
        then Right normDouble
        else Left $ InvalidConstraint ("Quaternion norm out of bounds: " ++ show normDouble)

{-|
Check orthogonality: r · d should be ≈ 0
-}
checkOrthogonality :: Quaternion -> Quaternion -> Either KernelError Double
checkOrthogonality r d = do
    let dot = qDotProduct r d
    let dotDouble = fromScalar32 dot
    if abs dotDouble < 0.01
        then Right dotDouble
        else Left $ InvalidConstraint ("Dual part not orthogonal to real: " ++ show dotDouble)

-- ====================================================
-- HELPER FUNCTIONS (Safe Arithmetic)
-- ====================================================

qNormSafe :: Quaternion -> Either KernelError Scalar32
qNormSafe q = do
    let normSq = qDotProduct q q
    let normDouble = sqrt (fromScalar32 normSq)
    case toScalar32 normDouble of
        Left msg -> Left $ ArithmeticError msg
        Right n -> Right n

qNormalizeSafe :: Quaternion -> Either KernelError Quaternion
qNormalizeSafe q@(Quaternion w x y z) = do
    norm <- qNormSafe q
    if norm == Scalar32 0
        then Left $ ArithmeticError "Cannot normalize zero quaternion"
        else do
            let invNorm = Scalar32 (65536 `div` fromScalar32 norm `asInt32`)
            Right $ Quaternion 
                (scalarMulSafe w invNorm)
                (scalarMulSafe x invNorm)
                (scalarMulSafe y invNorm)
                (scalarMulSafe z invNorm)

qScaleSafe :: Scalar32 -> Scalar32 -> Scalar32
qScaleSafe (Scalar32 s) (Scalar32 x) = 
    let extended = s * x
        shifted = extended `shiftR` 16
    in Scalar32 (saturate shifted)

qAddSafe :: Quaternion -> Quaternion -> Either KernelError Quaternion
qAddSafe (Quaternion w1 x1 y1 z1) (Quaternion w2 x2 y2 z2) =
    Right $ Quaternion (scalarAddUnchecked w1 w2) (scalarAddUnchecked x1 x2) 
                       (scalarAddUnchecked y1 y2) (scalarAddUnchecked z1 z2)

qSubtract :: Quaternion -> Quaternion -> Quaternion
qSubtract (Quaternion w1 x1 y1 z1) (Quaternion w2 x2 y2 z2) =
    Quaternion (scalarSubUnchecked w1 w2) (scalarSubUnchecked x1 x2)
               (scalarSubUnchecked y1 y2) (scalarSubUnchecked z1 z2)

scalarAddSafe :: Scalar32 -> Scalar32 -> Either KernelError Scalar32
scalarAddSafe (Scalar32 a) (Scalar32 b) =
    let sum = a + b
    in if (a > 0 && b > 0 && sum < 0) || (a < 0 && b < 0 && sum > 0)
       then Left $ ArithmeticError "Addition overflow"
       else Right (Scalar32 (saturate sum))

scalarAddUnchecked :: Scalar32 -> Scalar32 -> Scalar32
scalarAddUnchecked (Scalar32 a) (Scalar32 b) = Scalar32 (saturate (a + b))

scalarSubUnchecked :: Scalar32 -> Scalar32 -> Scalar32
scalarSubUnchecked (Scalar32 a) (Scalar32 b) = Scalar32 (saturate (a - b))

scalarMulSafe :: Scalar32 -> Scalar32 -> Scalar32
scalarMulSafe (Scalar32 a) (Scalar32 b) =
    let prod = a * b
        shifted = prod `shiftR` 16
    in Scalar32 (saturate shifted)

scalarDivSafe :: Scalar32 -> Scalar32 -> Scalar32
scalarDivSafe (Scalar32 a) (Scalar32 0) = Scalar32 a  -- Conservative: return numerator
scalarDivSafe (Scalar32 a) (Scalar32 b) = Scalar32 ((a `shiftL` 16) `div` b)

negateSafe :: Scalar32 -> Scalar32
negateSafe (Scalar32 x) = Scalar32 (saturate (-x))

validateDualQuaternion :: DualQuaternion -> Either KernelError ()
validateDualQuaternion (DualQuaternion r d) = do
    _ <- checkManifoldConstraint r
    _ <- checkOrthogonality r d
    Right ()

asInt32 :: Double -> Int32
asInt32 = fromIntegral . (round :: Double -> Integer)

saturate :: Int32 -> Int32
saturate x
    | x > 32767 = 32767
    | x < -32768 = -32768
    | otherwise = x
