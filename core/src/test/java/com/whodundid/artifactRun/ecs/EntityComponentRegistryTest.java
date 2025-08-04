package com.whodundid.artifactRun.ecs;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.ecs.components.*;
import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

import java.util.UUID;

public class EntityComponentRegistryTest {
    
    @BeforeEach
    void setup() {
        EntityComponentRegistry.resetRegistry();
    }
    
    @Test
    void defaultComponents_arePresent() {
        assertEquals(PositionComponent.class, EntityComponentRegistry.get(EntityComponentType.POSITION.name()));
        assertEquals(HealthComponent.class, EntityComponentRegistry.get(EntityComponentType.HEALTH.name()));
    }
    
    @Test
    void registerWithEnumType_works() {
        EntityComponentRegistry.register(EntityComponentType.INPUT, InputComponent.class);
        assertEquals(InputComponent.class, EntityComponentRegistry.get("INPUT"));
    }
    
    @Test
    void registerWithCustomString_addsNewEntry() {
        String id = "CUSTOM_" + UUID.randomUUID();
        class DummyComponent extends AbstractEntityComponent {
            DummyComponent() {
                super(EntityComponentType.RENDERER);
            }

            @Override
            public AbstractEntityComponent copy() {
                return new DummyComponent();
            }
        }

        
        EntityComponentRegistry.register(id, DummyComponent.class);
        assertEquals(DummyComponent.class, EntityComponentRegistry.get(id));
    }
    
    @Test
    void resetRegistry_clearsAndRestoresDefaults() {
        EntityComponentRegistry.register("EXTRA", SizeComponent.class);
        assertNotNull(EntityComponentRegistry.get("EXTRA"));
        
        EntityComponentRegistry.resetRegistry();
        
        assertNull(EntityComponentRegistry.get("EXTRA"));
        assertEquals(CollisionComponent.class, EntityComponentRegistry.get(EntityComponentType.COLLISION.name()));
    }
    
    @Test
    void getReturnsNull_whenUnregistered() {
        assertNull(EntityComponentRegistry.get("NON_EXISTENT_TYPE"));
    }
    
    @Test
    void register_overwritesExistingValue() {
        class AltPositionComponent extends AbstractEntityComponent {
            AltPositionComponent() {
                super(EntityComponentType.POSITION);
            }
            public AbstractEntityComponent copy() {
                return new AltPositionComponent();
            }
        }
        
        EntityComponentRegistry.register("POSITION", AltPositionComponent.class);
        assertEquals(AltPositionComponent.class, EntityComponentRegistry.get("POSITION"));
    }
    
}
