{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}

module Kernel.DualQuaternion
    ( qMul
    , qAdd
    , qConjugate
    , dqCompose
    , dqInverse
    , dqApply
    , qNorm
    , qNormalize
    ) where

import Prelude hiding ((.), id)
import Kernel.Core
import Kernel.FixedPoint

qMul :: Quaternion -> Quaternion -> Quaternion
qMul (Quaternion w1 x1 y1 z1) (Quaternion w2 x2 y2 z2) =
    Quaternion
        (scalarSub (scalarSub (scalarMul w1 w2) (scalarMul x1 x2)) 
                   (scalarAdd (scalarMul y1 y2) (scalarMul z1 z2)))
        (scalarAdd (scalarAdd (scalarMul w1 x2) (scalarMul x1 w2)) 
                   (scalarSub (scalarMul y1 z2) (scalarMul z1 y2)))
        (scalarAdd (scalarAdd (scalarMul w1 y2) (scalarMul y1 w2)) 
                   (scalarSub (scalarMul z1 x2) (scalarMul x1 z2)))
        (scalarAdd (scalarAdd (scalarMul w1 z2) (scalarMul z1 w2)) 
                   (scalarSub (scalarMul x1 y2) (scalarMul y1 x2)))

qAdd :: Quaternion -> Quaternion -> Quaternion
qAdd (Quaternion w1 x1 y1 z1) (Quaternion w2 x2 y2 z2) =
    Quaternion (scalarAdd w1 w2) (scalarAdd x1 x2) (scalarAdd y1 y2) (scalarAdd z1 z2)

qConjugate :: Quaternion -> Quaternion
qConjugate (Quaternion w x y z) = Quaternion w (scalarNegate x) (scalarNegate y) (scalarNegate z)

dqCompose :: DualQuaternion -> DualQuaternion -> DualQuaternion
dqCompose (DualQuaternion r1 d1) (DualQuaternion r2 d2) =
    DualQuaternion (qMul r1 r2) (qAdd (qMul d1 r2) (qMul r1 d2))

dqInverse :: DualQuaternion -> DualQuaternion
dqInverse (DualQuaternion r d) =
    let rConj = qConjugate r
        dConj = qConjugate d
    in DualQuaternion rConj (scalarNegate (qMul dConj rConj))

dqApply :: DualQuaternion -> Scalar32 -> Scalar32 -> Scalar32 -> (Scalar32, Scalar32, Scalar32)
dqApply dq x y z = (x, y, z)  -- Placeholder

qNorm :: Quaternion -> Scalar32
qNorm (Quaternion w x y z) =
    let ww = scalarMul w w
        xx = scalarMul x x
        yy = scalarMul y y
        zz = scalarMul z z
        sum1 = scalarAdd ww xx
        sum2 = scalarAdd yy zz
        sumAll = scalarAdd sum1 sum2
    in sumAll

qNormalize :: Quaternion -> Quaternion
qNormalize q =
    let norm = qNorm q
    in if norm == Scalar32 0 then q else
       Quaternion (scalarDiv (qW q) norm) 
                  (scalarDiv (qX q) norm)
                  (scalarDiv (qY q) norm)
                  (scalarDiv (qZ q) norm)
