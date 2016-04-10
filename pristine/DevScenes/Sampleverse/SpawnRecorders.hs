{-# LANGUAGE FlexibleContexts #-}
module DefaultStart where
import Rumpus

start :: OnStart
start = do
    removeChildren
    rootEntityID <- ask
    let recorderAt y = do
            myParent            ==> rootEntityID
            myShapeType         ==> CubeShape
            myPhysicsProperties ==> [Kinematic]
            myPose              ==> identity & translation . _y .~ y
            mySize              ==> 0.1
            myPdPatchFile       ==> "scenes/sampleverse/recorder"
            myOnCollisionStart  ==> \_ _ -> do
                hue <- liftIO randomIO
                myColor ==> hslColor hue 0.8 0.4 1
                sendPd "record-toggle" (Atom 1)
            myOnCollisionEnd    ==> \_ -> do
                sendPd "record-toggle" (Atom 0)
            myOnStart           ==> do
                samplerEntityID <- ask
                children <- forM [0..255] $ \i -> do
                    let x = fromIntegral i / 8 + 1
                    spawnEntity Transient $ do
                        myParent                 ==> samplerEntityID
                        myShapeType              ==> CubeShape
                        mySize                   ==> 1
                        myColor                  ==> V4 0.8 0.9 0.4 1
                        myPose                   ==> identity & translation . _x .~ x
                        myPhysicsProperties      ==> [NoPhysicsShape]
                        myInheritParentTransform ==> True
                return (Just (toDyn children))
            myOnUpdate          ==> withScriptData (\children -> do
                fftSample <- readPdArray "sample-fft" 0 256
                forM_ (zip children fftSample) $ \(childID, sample) -> runEntity childID $ do
                    let val = sample * 2
                    mySize  ==> (0.1 & _yz .~ realToFrac val)
                    myColor ==> hslColor (realToFrac val) 0.8 0.4
                )
    
    forM_ [1, 2] $ \y -> spawnEntity Transient $ recorderAt y
    return Nothing
