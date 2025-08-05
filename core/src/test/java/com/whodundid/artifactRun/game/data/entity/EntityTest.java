package com.whodundid.artifactRun.game.data.entity;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.entity.components.CollisionComponent;
import com.whodundid.artifactRun.game.data.entity.components.EntityRendererComponent;
import com.whodundid.artifactRun.game.data.entity.components.EntityRendererComponent.EntityAnimationState;
import com.whodundid.artifactRun.game.data.entity.components.FactionComponent;
import com.whodundid.artifactRun.game.data.entity.components.FactionComponent.FACTION;
import com.whodundid.artifactRun.game.data.entity.components.HealthComponent;
import com.whodundid.artifactRun.game.data.entity.components.InputComponent;
import com.whodundid.artifactRun.game.data.entity.components.PositionComponent;
import com.whodundid.artifactRun.game.data.entity.components.SizeComponent;
import com.whodundid.artifactRun.game.data.entity.components.VelocityComponent;

public class EntityTest {

    @Test
    void testCreateEntity_hasUniqueId() {
        Entity entity = new Entity();
        assertNotNull(entity.getObjectId());
    }

    @Test
    void testAddAndGetComponent() {
        Entity entity = new Entity();
        PositionComponent pos = new PositionComponent(1, 2);
        entity.addComponent(pos);

        PositionComponent fetched = entity.getComponent(PositionComponent.class);
        assertEquals(1, fetched.x);
        assertEquals(2, fetched.y);
    }

    @Test
    void testRemoveComponent() {
        Entity entity = new Entity();
        entity.addComponent(new HealthComponent(100, 90));
        entity.removeComponent(HealthComponent.class);
        assertFalse(entity.hasComponent(HealthComponent.class));
    }

    @Test
    void testComponentOverwrite() {
        Entity entity = new Entity();
        entity.addComponent(new PositionComponent(1, 1));
        entity.addComponent(new PositionComponent(9, 9));
        PositionComponent pos = entity.getComponent(PositionComponent.class);
        assertEquals(9, pos.x);
        assertEquals(9, pos.y);
    }

    @Test
    void testHasComponentWorks() {
        Entity entity = new Entity();
        assertFalse(entity.hasComponent(VelocityComponent.class));
        entity.addComponent(new VelocityComponent(3, 4));
        assertTrue(entity.hasComponent(VelocityComponent.class));
    }

    @Test
    void testNonexistentComponentReturnsNull() {
        Entity entity = new Entity();
        assertNull(entity.getComponent(InputComponent.class));
    }

    @Test
    void testSerializationRoundTrip() {
        Entity original = new Entity();
        original.addComponent(new PositionComponent(1.5f, 2.5f));
        original.addComponent(new HealthComponent(100, 80));

        String json = original.toJson();
        Entity loaded = Entity.fromJson(json);

        PositionComponent pos = loaded.getComponent(PositionComponent.class);
        HealthComponent hp = loaded.getComponent(HealthComponent.class);

        assertEquals(1.5f, pos.x, 0.001f);
        assertEquals(2.5f, pos.y, 0.001f);
        assertEquals(100, hp.maxHealth);
        assertEquals(80, hp.health);
    }

    @Test
    void testSerializationWithRendererComponent() {
        EntityRendererComponent rc = new EntityRendererComponent("player_idle");
        rc.isAnimated = true;
        rc.startingState = EntityAnimationState.IDLE_DOWN;
        rc.frameDuration = 0.1f;
        rc.looping = true;
        rc.animationFrames.put(EntityAnimationState.WALK_DOWN, List.of("walk1", "walk2", "walk3"));

        Entity entity = new Entity();
        entity.addComponent(rc);

        String json = entity.toJson();
        Entity deserialized = Entity.fromJson(json);

        EntityRendererComponent loaded = deserialized.getComponent(EntityRendererComponent.class);
        assertNotNull(loaded);
        assertEquals("player_idle", loaded.defaultSpriteId);
        assertTrue(loaded.isAnimated);
        assertEquals(0.1f, loaded.frameDuration);
        assertTrue(loaded.looping);
        assertEquals(List.of("walk1", "walk2", "walk3"), loaded.animationFrames.get(EntityAnimationState.WALK_DOWN));
    }

    @Test
    void testEntityCopyCreatesNewId() {
        Entity original = new Entity();
        Entity copy = new Entity(original);
        assertNotEquals(original.getObjectId(), copy.getObjectId());
    }

    @Test
    void testEntityCopyDeepCopiesComponents() {
        Entity original = new Entity();
        original.addComponent(new SizeComponent(16, 16));
        original.addComponent(new FactionComponent(FACTION.PLAYER));

        Entity copy = new Entity(original);

        SizeComponent originalSize = original.getComponent(SizeComponent.class);
        SizeComponent copiedSize = copy.getComponent(SizeComponent.class);
        assertNotSame(originalSize, copiedSize);
        assertEquals(originalSize.width, copiedSize.width);
    }

    @Test
    void testRendererComponentIsCopiedDeeply() {
        EntityRendererComponent rc = new EntityRendererComponent("player_idle");
        rc.isAnimated = true;
        rc.startingState = EntityAnimationState.WALK_LEFT;
        rc.frameDuration = 0.2f;
        rc.looping = true;
        rc.animationFrames.put(EntityAnimationState.WALK_LEFT, List.of("walk_l1", "walk_l2"));

        Entity entity = new Entity();
        entity.addComponent(rc);
        Entity clone = new Entity(entity);

        EntityRendererComponent clonedRc = clone.getComponent(EntityRendererComponent.class);

        assertNotNull(clonedRc);
        assertEquals(rc.defaultSpriteId, clonedRc.defaultSpriteId);
        assertEquals(rc.startingState, clonedRc.startingState);
        assertEquals(rc.frameDuration, clonedRc.frameDuration);
        assertNotSame(rc.animationFrames.get(EntityAnimationState.WALK_LEFT),
                      clonedRc.animationFrames.get(EntityAnimationState.WALK_LEFT));
    }

    @Test
    void testMultipleComponentTypesWorkTogether() {
        Entity e = new Entity();
        e.addComponent(new HealthComponent(100, 99));
        e.addComponent(new PositionComponent(2, 3));
        e.addComponent(new VelocityComponent(1, 1));
        e.addComponent(new SizeComponent(16, 16));
        e.addComponent(new CollisionComponent(true));

        assertTrue(e.hasComponent(HealthComponent.class));
        assertTrue(e.hasComponent(PositionComponent.class));
        assertTrue(e.hasComponent(VelocityComponent.class));
        assertTrue(e.hasComponent(SizeComponent.class));
        assertTrue(e.hasComponent(CollisionComponent.class));
    }

    @Test
    void testComponentIsolationAfterCopy() {
        Entity original = new Entity();
        PositionComponent pos = new PositionComponent(1, 2);
        original.addComponent(pos);

        Entity copy = new Entity(original);
        PositionComponent copyPos = copy.getComponent(PositionComponent.class);
        copyPos.x = 99;

        assertNotEquals(pos.x, copyPos.x);
    }
    
}
