module AlphabetSoup where
import Rumpus

start :: Start
start = do

    let n = 0.3
    forM_ (take 100 $ cycle ['!'..'~']) $ \letter -> do
        printIO letter
        pos <- V3 <$> randomRange (-n,n)
                  <*> randomRange (-n,n)
                  <*> randomRange (-n,n)

        let (V3 x y z) = pos
        spawnChild_ $ do
            myPose          ==> position pos
            mySize          ==> 0.01
            myText          ==> [letter]
            myTextPose      ==> position (V3 0 1 0)
            myUpdate ==> do
                now <- getNow
                let n = (now + pos ^. _x + pos ^. _y) * 0.5
                setPositionRotationSize
                    (pos & _x +~ sin n & _y +~ cos n)
                    (axisAngle pos n)
                    (realToFrac (sin n*0.1))
                --setColor (colorHSL (x+(sin n * 0.3)) 0.5 0.5)