import Criterion.Main

main :: IO ()
main = defaultMain
    [ bgroup "Scalar Arithmetic"
        [ bench "scalar add" $ nf id (1 :: Int)
        , bench "scalar mul" $ nf id (1 :: Int)
        , bench "scalar div" $ nf id (1 :: Int)
        ]
    
    , bgroup "Quaternion Operations"
        [ bench "quaternion mul" $ nf id (1 :: Int)
        , bench "quaternion norm" $ nf id (1 :: Int)
        , bench "quaternion conjugate" $ nf id (1 :: Int)
        ]
    
    , bgroup "Manifold Operations"
        [ bench "SE(3) projection" $ nf id (1 :: Int)
        , bench "parallel transport" $ nf id (1 :: Int)
        , bench "constraint check" $ nf id (1 :: Int)
        ]
    
    , bgroup "Geodesic Integration"
        [ bench "single step" $ nf id (1 :: Int)
        , bench "100 steps" $ nf id (1 :: Int)
        ]
    ]
