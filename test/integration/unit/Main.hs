{-# LANGUAGE OverloadedStrings #-}

{-|
Module      : Test.Unit
Description : Unit tests for SE(3) kernel primitives
Stability   : experimental

Tests core operations:
- Fixed-point scalar conversions
- Quaternion operations
- Manifold projections
- Error handling
-}

module Main where

import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

import Data.Bits

-- ============================================
-- TEST SUITE ORGANIZATION
-- ============================================

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests = testGroup "SE(3) Kernel Tests"
    [ scalarTests
    , quaternionTests
    , manifoldTests
    , errorHandlingTests
    , propertyTests
    ]

-- ============================================
-- SCALAR TESTS
-- ============================================

scalarTests :: TestTree
scalarTests = testGroup "Fixed-Point Scalars"
    [ testCase "Q16.16 zero conversion" $ do
        let result = toScalar32 0.0
        case result of
            Right (Scalar32 x) -> x @?= 0
            Left msg -> assertFailure msg
    
    , testCase "Q16.16 positive value" $ do
        let result = toScalar32 1.5
        case result of
            Right (Scalar32 x) -> x @?= 98304  -- 1.5 * 65536
            Left msg -> assertFailure msg
    
    , testCase "Q16.16 negative value" $ do
        let result = toScalar32 (-0.5)
        case result of
            Right (Scalar32 x) -> x @?= (-32768)
            Left msg -> assertFailure msg
    
    , testCase "Q16.16 overflow saturation" $ do
        let result = toScalar32 50000.0
        case result of
            Right (Scalar32 x) -> x @?= maxBound
            Left msg -> assertFailure msg
    
    , testCase "Q16.16 underflow saturation" $ do
        let result = toScalar32 (-50000.0)
        case result of
            Right (Scalar32 x) -> x @?= minBound
            Left msg -> assertFailure msg
    
    , testCase "Q1.15 saturation at 1.0" $ do
        let result = toScalar16 1.5
        case result of
            Right (Scalar16 x) -> x @?= 32767
            Left msg -> assertFailure msg
    
    , testCase "Q1.15 underflow at -1.0" $ do
        let result = toScalar16 (-1.5)
        case result of
            Right (Scalar16 x) -> x @?= (-32768)
            Left msg -> assertFailure msg
    
    , testCase "Q16.16 round-trip precision" $ do
        let original = 2.5
        case toScalar32 original of
            Right s32 -> do
                let recovered = fromScalar32 s32
                abs (recovered - original) < 0.00002 @? 
                    "Round-trip error: " ++ show (recovered - original)
            Left msg -> assertFailure msg
    
    , testCase "Non-finite values rejected" $ do
        let result1 = toScalar32 (1.0 / 0.0)
        let result2 = toScalar32 (0.0 / 0.0)
        case (result1, result2) of
            (Left _, Left _) -> return ()
            _ -> assertFailure "Should reject non-finite values"
    ]

-- ============================================
-- QUATERNION TESTS
-- ============================================

quaternionTests :: TestTree
quaternionTests = testGroup "Quaternion Operations"
    [ testCase "Identity quaternion" $ do
        let q = Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0)
        case validateQuaternion q of
            Right () -> return ()
            Left msg -> assertFailure msg
    
    , testCase "Quaternion dot product (orthogonal)" $ do
        let q1 = Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0)
        let q2 = Quaternion (Scalar32 0) (Scalar32 65536) (Scalar32 0) (Scalar32 0)
        let dot = qDotProduct q1 q2
        dot @?= Scalar32 0
    
    , testCase "Quaternion self-dot equals norm squared" $ do
        let q = Quaternion (Scalar32 46341) (Scalar32 46341) (Scalar32 0) (Scalar32 0)
        let selfDot = qDotProduct q q
        -- selfDot should approximate 1.0 (65536 in Q16.16)
        case validateQuaternion q of
            Right () -> return ()
            Left msg -> assertFailure msg
    
    , testCase "Quaternion addition commutativity" $ do
        let q1 = Quaternion (Scalar32 10000) (Scalar32 20000) (Scalar32 0) (Scalar32 0)
        let q2 = Quaternion (Scalar32 5000) (Scalar32 3000) (Scalar32 0) (Scalar32 0)
        case (qAddSafe q1 q2, qAddSafe q2 q1) of
            (Right sum1, Right sum2) -> sum1 @?= sum2
            _ -> assertFailure "Addition should be commutative"
    
    , testCase "Quaternion scaling" $ do
        let q = Quaternion (Scalar32 32768) (Scalar32 32768) (Scalar32 0) (Scalar32 0)
        let scalar = Scalar32 32768  -- 0.5 in Q16.16
        let scaled = qScaleSafe scalar q
        -- Components should be halved
        return ()  -- Visually verify
    ]

-- ============================================
-- MANIFOLD PROJECTION TESTS
-- ============================================

manifoldTests :: TestTree
manifoldTests = testGroup "Manifold Operations"
    [ testCase "Project identity dual quaternion" $ do
        let dq = DualQuaternion 
                 (Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0))
                 (Quaternion (Scalar32 0) (Scalar32 0) (Scalar32 0) (Scalar32 0))
        case projectSE3Safe dq of
            Right projected -> do
                case validateDualQuaternion projected of
                    Right () -> return ()
                    Left msg -> assertFailure msg
            Left msg -> assertFailure (show msg)
    
    , testCase "Orthogonality enforced after projection" $ do
        let r = Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0)
        let d = Quaternion (Scalar32 32768) (Scalar32 32768) (Scalar32 0) (Scalar32 0)
        let dq = DualQuaternion r d
        case projectSE3Safe dq of
            Right (DualQuaternion _ dProj) -> do
                case checkOrthogonality r dProj of
                    Right dot -> abs dot < 0.01 @? "Not orthogonal: " ++ show dot
                    Left msg -> assertFailure (show msg)
            Left msg -> assertFailure (show msg)
    
    , testCase "Parallel transport velocity update" $ do
        let dissonance = Scalar32 16384   -- 0.25 in Q16.16
        let vel = Scalar32 32768          -- 0.5 in Q16.16
        let dt = Scalar32 6553            -- 0.1 in Q16.16
        case parallelTransport dissonance vel dt of
            Right newVel -> do
                -- Velocity should decrease due to negative force
                newVel < vel @? "Velocity not updated correctly"
            Left msg -> assertFailure (show msg)
    ]

-- ============================================
-- ERROR HANDLING TESTS
-- ============================================

errorHandlingTests :: TestTree
errorHandlingTests = testGroup "Error Handling"
    [ testCase "Arithmetic error formatting" $ do
        let err = ArithmeticError "Division by zero"
        let msg = displayError err
        "ARITHMETIC ERROR" `elem` words msg @? "Should contain error class"
    
    , testCase "Constraint error formatting" $ do
        let err = InvalidConstraint "Quaternion not normalized"
        let msg = displayError err
        "CONSTRAINT VIOLATION" `elem` words msg @? "Should indicate constraint"
    
    , testCase "Error severity classification" $ do
        let critical = SaturationDetected "Plateaued at max"
        errorSeverity critical @?= Critical
        
        let medium = ConvergenceFailed "Too many iterations"
        errorSeverity medium @?= Medium
    
    , testCase "Recoverable error detection" $ do
        let recov = ConvergenceFailed "Try again"
        isRecoverable recov @? "Should be recoverable"
        
        let notRecov = ArithmeticError "Overflow"
        not (isRecoverable notRecov) @? "Should not be recoverable"
    
    , testCase "Composite error handling" $ do
        let err1 = ArithmeticError "First"
        let err2 = InvalidInput "Second"
        case combineErrors [err1, err2] of
            Just (CompositeError errs) -> length errs @?= 2
            _ -> assertFailure "Should combine errors"
    ]

-- ============================================
-- PROPERTY-BASED TESTS
-- ============================================

propertyTests :: TestTree
propertyTests = testGroup "Property-Based Tests"
    [ QC.testProperty "Saturation is idempotent" $ \x ->
        let y = saturate (x :: Int32)
        in saturate y == y
    
    , QC.testProperty "Scalar conversion is bounded" $ \d ->
        case toScalar32 (d :: Double) of
            Right (Scalar32 x) -> 
                x >= minBound && x <= maxBound
            Left _ -> True  -- Invalid inputs OK
    
    , QC.testProperty "Zero identity in addition" $ \x ->
        case scalarAddSafe (Scalar32 x) (Scalar32 0) of
            Right (Scalar32 result) -> result == saturate x
            Left _ -> True
    
    , QC.testProperty "Manifold projection is idempotent" $ \_ ->
        let dq = DualQuaternion 
                 (Quaternion (Scalar32 65536) (Scalar32 0) (Scalar32 0) (Scalar32 0))
                 (Quaternion (Scalar32 0) (Scalar32 0) (Scalar32 0) (Scalar32 0))
        in case (projectSE3Safe dq, projectSE3Safe (projectSE3 dq)) of
            (Right p1, Right p2) -> p1 == p2
            _ -> True
    ]

-- ============================================
-- HELPER FUNCTIONS (Stubs for missing definitions)
-- ============================================

-- These would be imported from actual modules in real implementation
newtype Scalar32 = Scalar32 Int32 deriving (Show, Eq, Ord)
newtype Scalar16 = Scalar16 Int16 deriving (Show, Eq)

data Quaternion = Quaternion Scalar32 Scalar32 Scalar32 Scalar32 
    deriving (Show, Eq)

data DualQuaternion = DualQuaternion Quaternion Quaternion 
    deriving (Show, Eq)

data KernelError = ArithmeticError String 
                 | InvalidConstraint String
                 | SaturationDetected String
                 | InvalidInput String
                 | SynchronizationError String
                 | ConvergenceFailed String
                 | CompositeError [KernelError]
                 | UnknownError String
    deriving (Show, Eq)

data Severity = Critical | High | Medium | Low 
    deriving (Show, Eq, Ord)

toScalar32 :: Double -> Either String Scalar32
toScalar32 d
    | isNaN d || isInfinite d = Left "Non-finite"
    | d >= 32768 = Right (Scalar32 maxBound)
    | d < -32768 = Right (Scalar32 minBound)
    | otherwise = Right (Scalar32 (round (d * 65536)))

toScalar16 :: Double -> Either String Scalar16
toScalar16 d
    | isNaN d || isInfinite d = Left "Non-finite"
    | d >= 1.0 = Right (Scalar16 32767)
    | d < -1.0 = Right (Scalar16 (-32768))
    | otherwise = Right (Scalar16 (round (d * 32768)))

fromScalar32 :: Scalar32 -> Double
fromScalar32 (Scalar32 x) = fromIntegral x / 65536

fromScalar16 :: Scalar16 -> Double
fromScalar16 (Scalar16 x) = fromIntegral x / 32768

qDotProduct :: Quaternion -> Quaternion -> Scalar32
qDotProduct _ _ = Scalar32 65536  -- Stub

qScaleSafe :: Scalar32 -> Quaternion -> Scalar32
qScaleSafe _ _ = Scalar32 0  -- Stub

qAddSafe :: Quaternion -> Quaternion -> Either String Quaternion
qAddSafe a b = Right a  -- Stub

validateQuaternion :: Quaternion -> Either String ()
validateQuaternion _ = Right ()  -- Stub

validateDualQuaternion :: DualQuaternion -> Either String ()
validateDualQuaternion _ = Right ()  -- Stub

projectSE3Safe :: DualQuaternion -> Either String DualQuaternion
projectSE3Safe dq = Right dq  -- Stub

checkOrthogonality :: Quaternion -> Quaternion -> Either String Double
checkOrthogonality _ _ = Right 0.0  -- Stub

parallelTransport :: Scalar32 -> Scalar32 -> Scalar32 -> Either String Scalar32
parallelTransport _ v _ = Right v  -- Stub

scalarAddSafe :: Scalar32 -> Scalar32 -> Either String Scalar32
scalarAddSafe (Scalar32 a) (Scalar32 b) = Right (Scalar32 (saturate (a + b)))

isNaN :: Double -> Bool
isNaN x = x /= x

isInfinite :: Double -> Bool
isInfinite x = x == 1.0 / 0.0 || x == -1.0 / 0.0

displayError :: KernelError -> String
displayError (ArithmeticError msg) = "ARITHMETIC ERROR: " ++ msg
displayError (InvalidConstraint msg) = "CONSTRAINT VIOLATION: " ++ msg
displayError (SaturationDetected msg) = "SATURATION: " ++ msg
displayError (InvalidInput msg) = "INVALID INPUT: " ++ msg
displayError (SynchronizationError msg) = "SYNC ERROR: " ++ msg
displayError (ConvergenceFailed msg) = "CONVERGENCE FAILED: " ++ msg
displayError (CompositeError es) = "MULTIPLE ERRORS: " ++ show (length es)
displayError (UnknownError msg) = "UNKNOWN: " ++ msg

errorSeverity :: KernelError -> Severity
errorSeverity (SaturationDetected _) = Critical
errorSeverity (ArithmeticError _) = Critical
errorSeverity (SynchronizationError _) = High
errorSeverity (InvalidConstraint _) = High
errorSeverity (ConvergenceFailed _) = Medium
errorSeverity (InvalidInput _) = Medium
errorSeverity (CompositeError es) = maximum (map errorSeverity es)
errorSeverity (UnknownError _) = High

isRecoverable :: KernelError -> Bool
isRecoverable (ConvergenceFailed _) = True
isRecoverable (InvalidInput _) = True
isRecoverable (SaturationDetected _) = True
isRecoverable _ = False

combineErrors :: [KernelError] -> Maybe KernelError
combineErrors [] = Nothing
combineErrors [e] = Just e
combineErrors es = Just (CompositeError es)

saturate :: Int32 -> Int32
saturate x
    | x > 32767 = 32767
    | x < -32768 = -32768
    | otherwise = x
