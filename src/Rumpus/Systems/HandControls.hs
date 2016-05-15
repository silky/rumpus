{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MultiWayIf #-}
{-# LANGUAGE RecordWildCards #-}
module Rumpus.Systems.HandControls where
import PreludeExtra

import Rumpus.Systems.Drag
import Rumpus.Systems.Hands
import Rumpus.Systems.Physics
import Rumpus.Systems.Attachment
import Rumpus.Systems.Creator
import Rumpus.Systems.Haptics
import Rumpus.Systems.Teleport
import Rumpus.Systems.SceneEditor
import Rumpus.Systems.Scene

tickHandControlsSystem :: ECSMonad ()
tickHandControlsSystem = do
    let editSceneWithHand whichHand handEntityID otherHandEntityID event = case event of
            HandStateEvent hand -> do
                -- Shift the hands down a bit, since OpenVR gives us the position
                -- of center of the controller's ring rather than its body
                let newHandPoseRaw = hand ^. hndMatrix
                    handRotation = newHandPoseRaw ^. _m33
                    handOffset = handRotation !* V3 0 0 0.05
                    newHandPose = newHandPoseRaw & translation +~ handOffset
                setEntityPose handEntityID newHandPose
                continueDrag handEntityID
                continueHapticDrag whichHand newHandPose
                updateBeam whichHand
            HandButtonEvent HandButtonGrip ButtonDown -> do
                beginBeam whichHand
            HandButtonEvent HandButtonGrip ButtonUp -> do
                endBeam whichHand
            HandButtonEvent HandButtonTrigger ButtonDown -> do
                initiateGrab whichHand handEntityID otherHandEntityID
            HandButtonEvent HandButtonTrigger ButtonUp -> do
                checkForDestruction whichHand
                endHapticDrag whichHand
                endDrag handEntityID
                detachAttachedEntities handEntityID

                -- Saving is currently disabled to simplify the alpha release
                -- (code will still be saved automatically)
                saveScene
            HandButtonEvent HandButtonStart ButtonDown -> do
                openEntityLibrary whichHand
            HandButtonEvent HandButtonStart ButtonUp -> do
                closeEntityLibrary whichHand
            _ -> return ()

    leftHandID  <- getLeftHandID
    rightHandID <- getRightHandID
    withLeftHandEvents  (editSceneWithHand LeftHand leftHandID  rightHandID)
    withRightHandEvents (editSceneWithHand RightHand rightHandID leftHandID)