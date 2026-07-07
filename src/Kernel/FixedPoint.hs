{-# LANGUAGE NoImplicitPrelude #-}

{-|
Module      : Kernel.FixedPoint
Description : Fixed-point arithmetic primitives (Q16.16 and Q1.15)
Stability   : stable

Provides hardware-safe fixed-point operations with saturation semantics.
All operations preserve 32-bit boundaries and prevent overflow.
-}

module Kernel.FixedPoint
    ( -- * Arithmetic Operations
      scalarAdd
    , scalarSub
    , scalarMul
    , scalarDiv
    , scalarAbs
    , scalarNegate
    
    -- * Comparison
    , scalarEq
    , scalarLt
    , scalarLte
    , scalarGt
    , scalarGte
    , scalarMax
    , scalarMin
    
    -- * Utilities
    , scalarShiftL
    , scalarShiftR
    , scalarToDouble
    , doubleToScalar
    ) where

import Prelude hiding ((.), id)
import Kernel.Core
import Data.Bits

-- ====================================================
-- BASIC ARITHMETIC (with Saturation)
-- ====================================================

{-|
Add two scalars with saturation on overflow.

```
a + b = clip(a + b, -32768, 32767)
```
-}
scalarAdd :: Scalar32 -> Scalar32 -> Scalar32
scalarAdd (Scalar32 a) (Scalar32 b) = 
    let sum = a + b
        -- Check for overflow: same sign inputs, different sign output
        overflowed = ((a > 0 && b > 0 && sum < 0) || 
                      (a < 0 && b < 0 && sum > 0))
    in if overflowed
       then if a > 0 then Scalar32 maxBound else Scalar32 minBound
       else Scalar32 sum

{-|
Subtract two scalars with saturation.
-}
scalarSub :: Scalar32 -> Scalar32 -> Scalar32
scalarSub a b = scalarAdd a (scalarNegate b)

{-|
Multiply two Q16.16 scalars.

Key: Result has 32 fractional bits, must shift right by 16.
-}
scalarMul :: Scalar32 -> Scalar32 -> Scalar32
scalarMul (Scalar32 a) (Scalar32 b) = 
    let extended = (fromIntegral a :: Int64) * fromIntegral b
        shifted = extended `shiftR` 16
        saturated = max (-32768) (min 32767 shifted)
    in Scalar32 (fromIntegral saturated)

{-|
Divide two scalars (with protection against division by zero).

Formula: (a / b) = (a << 16) / b
-}
scalarDiv :: Scalar32 -> Scalar32 -> Scalar32
scalarDiv _ (Scalar32 0) = Scalar32 0  -- Conservative: return 0 on div-by-zero
scalarDiv (Scalar32 a) (Scalar32 b) = 
    let extended = (fromIntegral a :: Int64) `shiftL` 16
        result = extended `div` fromIntegral b
        saturated = max (-32768) (min 32767 result)
    in Scalar32 (fromIntegral saturated)

{-|
Absolute value with saturation protection.

Note: abs(minBound) = minBound (since -(−32768) would overflow)
-}
scalarAbs :: Scalar32 -> Scalar32
scalarAbs (Scalar32 x)
    | x == minBound = Scalar32 maxBound  -- Special case to prevent overflow
    | otherwise = Scalar32 (abs x)

{-|
Negate a scalar with saturation.
-}
scalarNegate :: Scalar32 -> Scalar32
scalarNegate (Scalar32 x)
    | x == minBound = Scalar32 maxBound  -- -(−32768) would overflow
    | otherwise = Scalar32 (-x)

-- ====================================================
-- COMPARISON OPERATIONS
-- ====================================================

scalarEq :: Scalar32 -> Scalar32 -> Bool
scalarEq (Scalar32 a) (Scalar32 b) = a == b

scalarLt :: Scalar32 -> Scalar32 -> Bool
scalarLt (Scalar32 a) (Scalar32 b) = a < b

scalarLte :: Scalar32 -> Scalar32 -> Bool
scalarLte (Scalar32 a) (Scalar32 b) = a <= b

scalarGt :: Scalar32 -> Scalar32 -> Bool
scalarGt (Scalar32 a) (Scalar32 b) = a > b

scalarGte :: Scalar32 -> Scalar32 -> Bool
scalarGte (Scalar32 a) (Scalar32 b) = a >= b

scalarMax :: Scalar32 -> Scalar32 -> Scalar32
scalarMax a b = if scalarGt a b then a else b

scalarMin :: Scalar32 -> Scalar32 -> Scalar32
scalarMin a b = if scalarLt a b then a else b

-- ====================================================
-- BIT OPERATIONS
-- ====================================================

{-|
Left shift with saturation (multiplication by power of 2).
-}
scalarShiftL :: Scalar32 -> Int -> Scalar32
scalarShiftL (Scalar32 x) n
    | n < 0 = Scalar32 x  -- No negative shifts
    | n > 30 = if x > 0 then Scalar32 maxBound else Scalar32 minBound
    | otherwise = 
        let shifted = x `shiftL` n
            saturated = max (-32768) (min 32767 shifted)
        in Scalar32 saturated

{-|
Right shift with sign extension (division by power of 2).
-}
scalarShiftR :: Scalar32 -> Int -> Scalar32
scalarShiftR (Scalar32 x) n
    | n < 0 = Scalar32 x
    | otherwise = Scalar32 (x `shiftR` n)

-- ====================================================
-- CONVERSION
-- ====================================================

{-|
Convert fixed-point to floating-point for display/debugging.
-}
scalarToDouble :: Scalar32 -> Double
scalarToDouble (Scalar32 x) = fromIntegral x / 65536

{-|
Convert floating-point to fixed-point with clamping.
-}
doubleToScalar :: Double -> Scalar32
doubleToScalar d
    | isNaN d || isInfinite d = Scalar32 0
    | d >= 32768 = Scalar32 maxBound
    | d < -32768 = Scalar32 minBound
    | otherwise = Scalar32 (round (d * 65536))

-- ====================================================
-- HELPER FUNCTIONS
-- ====================================================

isNaN :: Double -> Bool
isNaN x = x /= x

isInfinite :: Double -> Bool
isInfinite x = x == 1.0 / 0.0 || x == -1.0 / 0.0
