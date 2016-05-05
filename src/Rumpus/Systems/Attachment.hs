{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
module Rumpus.Systems.Attachment where
import PreludeExtra

import Rumpus.Systems.Shared
import Rumpus.Systems.Physics
import qualified Data.Set as Set
data Attachment = Attachment
    { atcToEntityID :: !EntityID
    , atcOffset     :: !(M44 GLfloat)
    } deriving (Ord, Eq)
type Attachments = Set Attachment

defineComponentKey ''Attachments

initAttachmentSystem :: (MonadIO m, MonadState ECS m) => m ()
initAttachmentSystem = do
    registerComponent "Attachments" myAttachments (newComponentInterface myAttachments)

tickAttachmentSystem :: (MonadIO m, MonadState ECS m) => m ()
tickAttachmentSystem =
    forEntitiesWithComponent myAttachments $
        \(entityID, attachments) ->
            forM_ attachments $ \(Attachment toEntityID offset) -> do
                pose <- getEntityPose entityID
                setEntityPose (pose `addMatrix` offset) toEntityID

attachEntity :: (MonadIO m, MonadState ECS m) => EntityID -> EntityID -> Bool -> m ()
attachEntity entityID toEntityID exclusive = do
    -- Detach any current attachments
    when exclusive $
        detachAttachedEntities entityID

    entityPose   <- getEntityPose entityID
    toEntityPose <- getEntityPose toEntityID
    let offset = toEntityPose `subtractMatrix` entityPose

    addAttachmentToSet entityID (Attachment toEntityID offset)

    withEntityRigidBody toEntityID $ \rigidBody ->
        setRigidBodyKinematic rigidBody True

detachAttachedEntity :: (HasComponents s, MonadState s m) => EntityID -> EntityID -> m ()
detachAttachedEntity ofEntityID entityID =
    modifyEntityComponent ofEntityID myAttachments
        (Set.filter (not . (== entityID) . atcToEntityID))

detachAttachedEntities :: (MonadState ECS m, MonadIO m) => EntityID -> m ()
detachAttachedEntities ofEntityID =
    withAttachments ofEntityID $ \attachments -> do
        forM_ attachments $ \(Attachment attachedEntityID _offset) -> do

            properties <- getEntityProperties attachedEntityID
            unless (Floating `elem` properties) $
                withEntityRigidBody attachedEntityID $ \rigidBody ->
                    setRigidBodyKinematic rigidBody False

        removeEntityComponent myAttachments ofEntityID

addAttachmentToSet :: (MonadState s m, HasComponents s) => EntityID -> Attachment -> m ()
addAttachmentToSet entityID attachment =
    appendEntityComponent entityID myAttachments (Set.singleton attachment)

withAttachments :: MonadState ECS m => EntityID -> (Attachments -> m b) -> m ()
withAttachments entityID = withEntityComponent_ entityID myAttachments

getEntityAttachments :: (HasComponents s, MonadState s m) => EntityID -> m (Maybe Attachments)
getEntityAttachments entityID = getEntityComponent entityID myAttachments

isEntityAttachedTo :: (HasComponents s, MonadState s m) => EntityID -> EntityID -> m Bool
isEntityAttachedTo childID parentID = maybe False (Set.member childID . Set.map atcToEntityID) <$> getEntityAttachments parentID


