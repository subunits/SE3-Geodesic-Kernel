{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE RecordWildCards #-}

{-|
Module      : Kernel.Core
Description : Core type definitions and validation for SE(3) geodesic kernel
Stability   : experimental

This module defines the fundamental algebraic structures used throughout the
SE(3) geodesic kernel, including:

- Fixed-point scalar types (Q1.15 and Q16.16)
- Quaternion operations with hardware-safe semantics
- Dual quaternion representations
- Agent state tracking
-}

module Kernel.Core
    ( -- * Scalar Types
      Scalar32
    , Scalar16
    , toScalar32
    , toScalar16
    , fromScalar32
    , fromScalar16
    
    -- * Quaternion Types
    , Quaternion(..)
    , DualQuaternion(..)
    
    -- * Agent State
    , Agent(..)
    , AgentConfig(..)
    
    -- * Validation
    , validateScalar
    , validateQuaternion
    , validateAgent
    
    -- * Constants
    , epsilon
    , maxSaturation
    , minSaturation
    ) where

import Prelude hiding ((.))
import qualified Prelude as P
import Data.Bits
import GHC.Generics
import Control.DeepSeq

-- ====================================================
-- SCALAR TYPES (Fixed-Point Arithmetic)
-- ====================================================

-- | Q16.16 Fixed-Point: 16 integer bits, 16 fractional bits (32-bit total)
-- Range: [-32768, 32768) with 1/65536 precision
newtype Scalar32 = Scalar32 Int32 
    deriving (Show, Eq, Ord, Generic, NFData)

-- | Q1.15 Fixed-Point: 1 sign bit, 15 fractional bits (16-bit total)
-- Range: [-1, 1) with 1/32768 precision (hardware-friendly)
newtype Scalar16 = Scalar16 Int16
    deriving (Show, Eq, Ord, Generic, NFData)

-- Conversion functions with validation
toScalar32 :: Double -> Either String Scalar32
toScalar32 d
    | isNaN d || isInfinite d = Left "Non-finite double value"
    | d >= 32768 = Right (Scalar32 maxBound)
    | d < -32768 = Right (Scalar32 minBound)
    | otherwise = Right (Scalar32 (round (d * 65536)))

toScalar16 :: Double -> Either String Scalar16
toScalar16 d
    | isNaN d || isInfinite d = Left "Non-finite double value"
    | d >= 1.0 = Right (Scalar16 32767)
    | d < -1.0 = Right (Scalar16 (-32768))
    | otherwise = Right (Scalar16 (round (d * 32768)))

fromScalar32 :: Scalar32 -> Double
fromScalar32 (Scalar32 x) = P.fromIntegral x / 65536

fromScalar16 :: Scalar16 -> Double
fromScalar16 (Scalar16 x) = P.fromIntegral x / 32768

-- ====================================================
-- QUATERNION TYPES
-- ====================================================

-- | Quaternion with high-precision fixed-point components
-- Invariant: Should be normalized (w² + x² + y² + z² ≈ 1)
data Quaternion = Quaternion
    { qW :: !Scalar32
    , qX :: !Scalar32
    , qY :: !Scalar32
    , qZ :: !Scalar32
    } deriving (Show, Eq, Generic, NFData)

-- | Dual Quaternion: (real, dual) pair
-- Represents SE(3) transformations with rotation and translation
-- Invariant: real part is unit quaternion, dual part is orthogonal to real
data DualQuaternion = DualQuaternion
    { realPart :: !Quaternion
    , dualPart :: !Quaternion
    } deriving (Show, Eq, Generic, NFData)

-- ====================================================
-- AGENT STATE
-- ====================================================

-- | An agent navigating the Ricci-flat manifold
data Agent = Agent
    { agentPos       :: !DualQuaternion  -- Current pose (rotation + translation)
    , agentVel       :: !Scalar32        -- Velocity along geodesic
    , agentResonance :: !Scalar32        -- Internal frequency signature
    , agentMass      :: !Scalar32        -- Inertial mass (filters high-freq noise)
    } deriving (Show, Eq, Generic, NFData)

-- | Configuration for agent initialization
data AgentConfig = AgentConfig
    { cfgInitialPos       :: !DualQuaternion
    , cfgInitialVel       :: !Scalar32
    , cfgInitialResonance :: !Scalar32
    , cfgMass             :: !Scalar32
    } deriving (Show, Generic, NFData)

-- ====================================================
-- VALIDATION FUNCTIONS
-- ====================================================

-- | Validate that a scalar is within valid range
validateScalar :: Scalar32 -> Either String ()
validateScalar (Scalar32 x)
    | x > maxBound = Left "Scalar overflow"
    | x < minBound = Left "Scalar underflow"
    | otherwise = Right ()

-- | Validate quaternion normalization (allowing small epsilon tolerance)
validateQuaternion :: Quaternion -> Either String ()
validateQuaternion q = do
    let normSq = qDotProduct q q
    let normDouble = fromScalar32 normSq
    if abs (normDouble - 1.0) > 0.01
        then Left $ "Quaternion not normalized: " P.++ show normDouble
        else Right ()

-- | Validate agent state consistency
validateAgent :: Agent -> Either String ()
validateAgent Agent{..} = do
    validateQuaternion (realPart agentPos)
    validateQuaternion (dualPart agentPos)
    Right ()

-- ====================================================
-- QUATERNION OPERATIONS (Low-level, Hardware-Safe)
-- ====================================================

-- | Quaternion dot product (fixed-point safe)
qDotProduct :: Quaternion -> Quaternion -> Scalar32
qDotProduct (Quaternion w1 x1 y1 z1) (Quaternion w2 x2 y2 z2) =
    let Scalar32 pw = scalarMul w1 w2
        Scalar32 px = scalarMul x1 x2
        Scalar32 py = scalarMul y1 y2
        Scalar32 pz = scalarMul z1 z2
        -- Shift back to correct Q16.16 alignment after multiplication
        s = (pw `shiftR` 16) + (px `shiftR` 16) + (py `shiftR` 16) + (pz `shiftR` 16)
    in Scalar32 (saturate s)

-- | Scalar multiplication with saturation
scalarMul :: Scalar32 -> Scalar32 -> Scalar32
scalarMul (Scalar32 a) (Scalar32 b) = 
    Scalar32 (saturate (a * b))

-- | Saturate to prevent overflow
saturate :: Int32 -> Int32
saturate x
    | x > fromIntegral (maxBound :: Int16) = fromIntegral (maxBound :: Int16)
    | x < fromIntegral (minBound :: Int16) = fromIntegral (minBound :: Int16)
    | otherwise = x

-- ====================================================
-- CONSTANTS
-- ====================================================

-- | Machine epsilon for fixed-point comparison
epsilon :: Scalar32
epsilon = Scalar32 1  -- 1/65536 ≈ 0.0000153

-- | Maximum saturation value (plateau)
maxSaturation :: Scalar32
maxSaturation = Scalar32 32767

-- | Minimum saturation value
minSaturation :: Scalar32
minSaturation = Scalar32 (-32768)
