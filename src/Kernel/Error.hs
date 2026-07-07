{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

{-|
Module      : Kernel.Error
Description : Error types and handling for SE(3) kernel operations
Stability   : stable

Defines comprehensive error types for all kernel operations, with
human-readable messages suitable for debugging and logging.
-}

module Kernel.Error
    ( -- * Error Types
      KernelError(..)
    , ErrorContext(..)
    
    -- * Error Handling
    , displayError
    , errorSeverity
    , Severity(..)
    
    -- * Utilities
    , annotateError
    , combineErrors
    ) where

import GHC.Generics
import Control.DeepSeq
import Data.List (intercalate)

-- ====================================================
-- ERROR TYPES
-- ====================================================

{-|
Comprehensive error type for kernel operations.

Each constructor carries a description suitable for debugging.
-}
data KernelError
    -- | Arithmetic overflow, underflow, or division by zero
    = ArithmeticError String
    
    -- | Manifold constraint violation (e.g., unit quaternion not normalized)
    | InvalidConstraint String
    
    -- | Fixed-point saturation detected
    | SaturationDetected String
    
    -- | Invalid input parameters
    | InvalidInput String
    
    -- | Hardware synchronization or timing issue
    | SynchronizationError String
    
    -- | Convergence failure in iterative algorithm
    | ConvergenceFailed String
    
    -- | Multiple errors occurred
    | CompositeError [KernelError]
    
    -- | Unknown or unclassified error
    | UnknownError String
    deriving (Show, Eq, Generic, NFData)

{-|
Context for error annotations (optional metadata).
-}
data ErrorContext = ErrorContext
    { ctxOperation :: String      -- ^ What operation was being performed
    , ctxTimestamp :: String      -- ^ When the error occurred
    , ctxInput     :: Maybe String -- ^ Problematic input value
    } deriving (Show, Generic, NFData)

{-|
Error severity classification.
-}
data Severity = Critical | High | Medium | Low
    deriving (Show, Eq, Ord, Generic, NFData)

-- ====================================================
-- ERROR DISPLAY & ANALYSIS
-- ====================================================

{-|
Convert error to human-readable form with full context.
-}
displayError :: KernelError -> String
displayError err = case err of
    ArithmeticError msg -> 
        "ARITHMETIC ERROR: " ++ msg ++
        "\n  → Check for overflow/underflow in fixed-point operations" ++
        "\n  → Verify scalar ranges are within [-32768, 32768)"
    
    InvalidConstraint msg ->
        "CONSTRAINT VIOLATION: " ++ msg ++
        "\n  → Manifold geometry corrupted" ++
        "\n  → Try projecting back to SE(3)"
    
    SaturationDetected msg ->
        "SATURATION PLATEAU: " ++ msg ++
        "\n  → System locked at hardware maximum" ++
        "\n  → Apply Langevin jitter to recover"
    
    InvalidInput msg ->
        "INVALID INPUT: " ++ msg ++
        "\n  → Check input parameters against specification"
    
    SynchronizationError msg ->
        "SYNC ERROR: " ++ msg ++
        "\n  → Hardware clock skew detected" ++
        "\n  → Verify clock domain crossings"
    
    ConvergenceFailed msg ->
        "CONVERGENCE FAILURE: " ++ msg ++
        "\n  → Algorithm did not converge in expected time" ++
        "\n  → Increase iteration count or adjust step size"
    
    CompositeError errs ->
        "MULTIPLE ERRORS (" ++ show (length errs) ++ "):\n" ++
        intercalate "\n" (map displayError errs)
    
    UnknownError msg ->
        "UNKNOWN ERROR: " ++ msg

{-|
Classify error severity for logging/monitoring.
-}
errorSeverity :: KernelError -> Severity
errorSeverity err = case err of
    SaturationDetected _    -> Critical
    ArithmeticError _       -> Critical
    SynchronizationError _  -> High
    InvalidConstraint _     -> High
    ConvergenceFailed _     -> Medium
    InvalidInput _          -> Medium
    CompositeError errs     -> maximum (map errorSeverity errs)
    UnknownError _          -> High

-- ====================================================
-- ERROR MANIPULATION
-- ====================================================

{-|
Add context information to an error.
-}
annotateError :: ErrorContext -> KernelError -> KernelError
annotateError ctx err = case err of
    ArithmeticError msg ->
        ArithmeticError $ msg ++ 
        "\n  [" ++ ctxOperation ctx ++ "]" ++
        maybe "" ("\n  Input: " ++) (ctxInput ctx)
    other -> other

{-|
Combine multiple errors into a single composite error.
-}
combineErrors :: [KernelError] -> Maybe KernelError
combineErrors [] = Nothing
combineErrors [e] = Just e
combineErrors es = Just (CompositeError es)

-- ====================================================
-- UTILITIES
-- ====================================================

{-|
Format error for logging (compact, single-line).
-}
formatErrorLog :: KernelError -> String
formatErrorLog (ArithmeticError msg) = "ArithErr: " ++ msg
formatErrorLog (InvalidConstraint msg) = "Constraint: " ++ msg
formatErrorLog (SaturationDetected msg) = "Saturated: " ++ msg
formatErrorLog (InvalidInput msg) = "BadInput: " ++ msg
formatErrorLog (SynchronizationError msg) = "SyncErr: " ++ msg
formatErrorLog (ConvergenceFailed msg) = "NoConverge: " ++ msg
formatErrorLog (CompositeError errs) = "Multiple[" ++ show (length errs) ++ "]"
formatErrorLog (UnknownError msg) = "Unknown: " ++ msg

{-|
Check if error is recoverable (i.e., can retry with adjusted parameters).
-}
isRecoverable :: KernelError -> Bool
isRecoverable err = case err of
    ConvergenceFailed _ -> True
    InvalidInput _ -> True
    SaturationDetected _ -> True  -- Apply jitter to recover
    _ -> False
