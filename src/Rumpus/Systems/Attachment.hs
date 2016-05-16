{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
module Rumpus.Systems.Attachment where
import PreludeExtra

import Rumpus.Systems.Shared
import Rumpus.Systems.Physics
import qualified Data.HashMap.Strict as Map

type Attachments = Map EntityID (M44 GLfloat)

defineComponentKey ''Attachments
defineComponentKeyWithType "Holder" [t|EntityID|]

initAttachmentSystem :: (MonadIO m, MonadState ECS m) => m ()
initAttachmentSystem = do
    registerComponent "Attachments" myAttachments (newComponentInterface myAttachments)
    registerComponent "Holder" myHolder $ (newComponentInterface myHolder)
        -- Haven't needed this yet, but defining it since it's logical enough
        { ciDeriveComponent = Just $ do
            withComponent_ myHolder $ \holderID -> do
                entityID <- ask
                attachEntityToEntity holderID entityID False
        , ciRemoveComponent = detachFromHolder >> removeComponent myHolder
        }

tickAttachmentSystem :: (MonadIO m, MonadState ECS m) => m ()
tickAttachmentSystem =
    forEntitiesWithComponent myAttachments $
        \(entityID, attachments) ->
            forM_ (Map.toList attachments) $ \(toEntityID, offset) -> do
                pose <- getEntityPose entityID
                setEntityPose toEntityID (pose `addMatrix` offset)

detachFromHolder :: (MonadIO m, MonadState ECS m, MonadReader EntityID m) => m ()
detachFromHolder = detachEntityFromHolder =<< ask

detachEntityFromHolder :: (MonadState ECS m, MonadIO m) => EntityID -> m ()
detachEntityFromHolder entityID = do
    traverseM_ (getEntityComponent entityID myHolder) $ \holderID -> do
        detachAttachedEntity holderID entityID

setAttachmentOffset newOffset = do
    withComponent_ myHolder $ \holderID -> do
        myID <- ask
        modifyEntityComponent holderID myAttachments (Map.adjust (const newOffset) myID)

attachEntity toEntityID = do
    holderID <- ask
    attachEntityToEntity holderID toEntityID False

attachEntityToEntity :: (MonadIO m, MonadState ECS m) => EntityID -> EntityID -> Bool -> m ()
attachEntityToEntity holderID toEntityID exclusive = do

    detachEntityFromHolder toEntityID

    -- Detach any current attachments
    when exclusive $
        detachAttachedEntities holderID

    entityPose   <- getEntityPose holderID
    toEntityPose <- getEntityPose toEntityID
    let offset = toEntityPose `subtractMatrix` entityPose

    appendAttachment holderID toEntityID offset
    runEntity toEntityID (myHolder ==> holderID)
    overrideSetKinematicMode toEntityID

detachAttachedEntity :: (MonadState ECS m, MonadIO m) => EntityID -> EntityID -> m ()
detachAttachedEntity holderID entityID = do
    restoreSetKinematicMode entityID
    modifyEntityComponent holderID myAttachments (Map.delete entityID)
    removeEntityComponent myHolder entityID

-- | Force kinematic mode to on to allow objects to be carried
overrideSetKinematicMode :: (MonadIO m, MonadState ECS m) => EntityID -> m ()
overrideSetKinematicMode entityID =
    withEntityRigidBody entityID $ \rigidBody ->
        setRigidBodyKinematic rigidBody True

-- | Restores the kinematic mode requested in the entity's myProperties
restoreSetKinematicMode :: (MonadIO m, MonadState ECS m) => EntityID -> m ()
restoreSetKinematicMode entityID = do
    properties <- getEntityProperties entityID
    unless (Floating `elem` properties) $
        withEntityRigidBody entityID $ \rigidBody ->
            setRigidBodyKinematic rigidBody False

detachAttachedEntities :: (MonadState ECS m, MonadIO m) => EntityID -> m ()
detachAttachedEntities holderID =
    withAttachments holderID $ \attachments -> do
        forM_ (Map.keys attachments) $ \attachedEntityID -> do
            restoreSetKinematicMode attachedEntityID
            removeEntityComponent myHolder attachedEntityID

        removeEntityComponent myAttachments holderID

appendAttachment :: (MonadState ECS m) => EntityID -> EntityID -> M44 GLfloat -> m ()
appendAttachment holderID entityID offset =
    appendEntityComponent holderID myAttachments (Map.singleton entityID offset)

withAttachments :: MonadState ECS m => EntityID -> (Attachments -> m b) -> m ()
withAttachments entityID = withEntityComponent_ entityID myAttachments

getEntityAttachments :: (MonadState ECS m) => EntityID -> m (Map EntityID (M44 GLfloat))
getEntityAttachments entityID = fromMaybe mempty <$> getEntityComponent entityID myAttachments

isEntityAttachedTo :: (MonadState ECS m) => EntityID -> EntityID -> m Bool
isEntityAttachedTo childID parentID = Map.member childID <$> getEntityAttachments parentID


