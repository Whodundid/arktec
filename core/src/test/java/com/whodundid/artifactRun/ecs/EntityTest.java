package com.whodundid.artifactRun.ecs;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.whodundid.artifactRun.ecs.components.CollisionComponent;
import com.whodundid.artifactRun.ecs.components.HealthComponent;
import com.whodundid.artifactRun.ecs.components.InputComponent;
import com.whodundid.artifactRun.ecs.components.PositionComponent;
import com.whodundid.artifactRun.ecs.components.RenderComponent;
import com.whodundid.artifactRun.ecs.components.SizeComponent;
import com.whodundid.artifactRun.ecs.components.TeamComponent;
import com.whodundid.artifactRun.ecs.components.VelocityComponent;

public class EntityTest {

    @Test
    public void testCreateEntity() {
        Entity entity = new Entity();
        assertNotNull(entity.getEntityId(), "Entity should have a unique ID");
    }

    @Test
    public void testAddAndGetComponent() {
        Entity entity = new Entity();
        PositionComponent pos = new PositionComponent(5, 10);
        entity.addComponent(pos);

        PositionComponent retrieved = entity.getComponent(PositionComponent.class);
        assertNotNull(retrieved);
        assertEquals(5, retrieved.x);
        assertEquals(10, retrieved.y);
    }

    @Test
    public void testRemoveComponent() {
        Entity entity = new Entity();
        entity.addComponent(new HealthComponent(100, 100));
        entity.removeComponent(HealthComponent.class);
        assertFalse(entity.hasComponent(HealthComponent.class));
    }

    @Test
    public void testJsonSerialization() {
        Entity original = new Entity();
        original.addComponent(new PositionComponent(1.5f, 2.5f));
        original.addComponent(new HealthComponent(100, 80));

        String json = original.toJson();
        Entity loaded = Entity.fromJson(json);

        PositionComponent pos = loaded.getComponent(PositionComponent.class);
        HealthComponent hp = loaded.getComponent(HealthComponent.class);

        assertNotNull(pos);
        assertEquals(1.5f, pos.x, 0.001f);
        assertEquals(2.5f, pos.y, 0.001f);

        assertNotNull(hp);
        assertEquals(100, hp.maxHealth);
        assertEquals(80, hp.health);
    }

    @Test
    public void testEntityCopyCreatesNewId() {
        Entity original = new Entity();
        Entity copy = new Entity(original);
        assertNotEquals(original.getEntityId(), copy.getEntityId(), "Copied entity should have a unique ID");
    }

    @Test
    public void testEntityCopyDeepCopiesComponents() {
        Entity original = new Entity();
        original.addComponent(new SizeComponent(32, 64));
        original.addComponent(new TeamComponent(TeamComponent.Team.PLAYER));

        Entity copy = new Entity(original);

        SizeComponent originalSize = original.getComponent(SizeComponent.class);
        SizeComponent copiedSize = copy.getComponent(SizeComponent.class);

        assertNotSame(originalSize, copiedSize);
        assertEquals(originalSize.width, copiedSize.width);
        assertEquals(originalSize.height, copiedSize.height);
    }

    @Test
    public void testAddComponentOverwritesOldOne() {
        Entity entity = new Entity();
        entity.addComponent(new PositionComponent(1, 1));
        entity.addComponent(new PositionComponent(9, 9)); // overwrite

        PositionComponent pos = entity.getComponent(PositionComponent.class);
        assertEquals(9, pos.x);
        assertEquals(9, pos.y);
    }

    @Test
    public void testNonexistentComponentReturnsNull() {
        Entity entity = new Entity();
        assertNull(entity.getComponent(InputComponent.class));
    }

    @Test
    public void testSerializationSkipsTransientComponent() {
        Entity entity = new Entity();
        entity.addComponent(new InputComponent(true, false, false, false, true));
        entity.addComponent(new VelocityComponent(3, 4));

        String json = entity.toJson();
        System.out.println(json);
        Entity deserialized = Entity.fromJson(json);
        
        assertTrue(deserialized.hasComponent(InputComponent.class));
        assertTrue(deserialized.hasComponent(VelocityComponent.class));
        
        InputComponent ic = deserialized.getComponent(InputComponent.class);
        
        assertFalse(ic.shoot, "Transient InputComponent fields should not have be serialized");
        assertTrue(json.contains("VELOCITY"));
    }

    @Test
    public void testHasComponentWorks() {
        Entity entity = new Entity();
        assertFalse(entity.hasComponent(RenderComponent.class));
        entity.addComponent(new RenderComponent((TextureRegion) null));
        assertTrue(entity.hasComponent(RenderComponent.class));
    }

    @Test
    public void testComponentMapIsolationInCopy() {
        Entity entity = new Entity();
        PositionComponent originalPosition = new PositionComponent(5, 10);
        entity.addComponent(originalPosition);

        Entity copy = new Entity(entity);
        PositionComponent copyPosition = copy.getComponent(PositionComponent.class);

        copyPosition.x = 99;
        assertNotEquals(originalPosition.x, copyPosition.x);
    }

    @Test
    public void testMultipleComponentTypes() {
        Entity entity = new Entity();
        entity.addComponent(new HealthComponent(100, 90));
        entity.addComponent(new PositionComponent(1, 1));
        entity.addComponent(new VelocityComponent(1, 0));
        entity.addComponent(new SizeComponent(16, 16));
        entity.addComponent(new CollisionComponent(true));

        assertTrue(entity.hasComponent(HealthComponent.class));
        assertTrue(entity.hasComponent(PositionComponent.class));
        assertTrue(entity.hasComponent(VelocityComponent.class));
        assertTrue(entity.hasComponent(SizeComponent.class));
        assertTrue(entity.hasComponent(CollisionComponent.class));
    }
    
}
