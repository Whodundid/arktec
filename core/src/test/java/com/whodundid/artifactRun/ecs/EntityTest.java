package com.whodundid.artifactRun.ecs;

import com.whodundid.artifactRun.ecs.components.HealthComponent;
import com.whodundid.artifactRun.ecs.components.PositionComponent;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

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
        assertNotNull(retrieved, "Component should be retrievable");
        assertEquals(5, retrieved.x);
        assertEquals(10, retrieved.y);
    }

    @Test
    public void testRemoveComponent() {
        Entity entity = new Entity();
        entity.addComponent(new HealthComponent(100, 100));
        entity.removeComponent(HealthComponent.class);
        assertFalse(entity.hasComponent(HealthComponent.class), "Component should be removed");
    }

    @Test
    public void testJsonSerialization() {
        Entity original = new Entity();
        original.addComponent(new PositionComponent(1.5f, 2.5f));
        original.addComponent(new HealthComponent(80, 100));

        String json = original.toJson();
        Entity loaded = Entity.fromJson(json);
        
        PositionComponent pos = loaded.getComponent(PositionComponent.class);
        HealthComponent hp = loaded.getComponent(HealthComponent.class);

        assertNotNull(pos);
        assertEquals(1.5f, pos.x, 0.001f);
        assertEquals(2.5f, pos.y, 0.001f);

        assertNotNull(hp);
        assertEquals(80, hp.health);
        assertEquals(100, hp.maxHealth);
    }
    
}
