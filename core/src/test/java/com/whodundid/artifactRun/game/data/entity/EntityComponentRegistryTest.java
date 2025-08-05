package com.whodundid.artifactRun.game.data.entity;

import static org.junit.jupiter.api.Assertions.*;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.entity.components.CollisionComponent;
import com.whodundid.artifactRun.game.data.entity.components.HealthComponent;
import com.whodundid.artifactRun.game.data.entity.components.InputComponent;
import com.whodundid.artifactRun.game.data.entity.components.PositionComponent;
import com.whodundid.artifactRun.game.data.entity.components.SizeComponent;

public class EntityComponentRegistryTest {
    
    @BeforeEach
    void setup() {
        EntityComponentRegistry.INSTANCE.resetRegistry();
    }
    
    @Test
    void defaultComponents_arePresent() {
        assertEquals(PositionComponent.class, EntityComponentRegistry.INSTANCE.get(EntityComponentType.POSITION.name()));
        assertEquals(HealthComponent.class, EntityComponentRegistry.INSTANCE.get(EntityComponentType.HEALTH.name()));
    }
    
    @Test
    void registerWithEnumType_works() {
        EntityComponentRegistry.INSTANCE.register(EntityComponentType.INPUT, InputComponent.class);
        assertEquals(InputComponent.class, EntityComponentRegistry.INSTANCE.get("INPUT"));
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

        
        EntityComponentRegistry.INSTANCE.register(id, DummyComponent.class);
        assertEquals(DummyComponent.class, EntityComponentRegistry.INSTANCE.get(id));
    }
    
    @Test
    void resetRegistry_clearsAndRestoresDefaults() {
        EntityComponentRegistry.INSTANCE.register("EXTRA", SizeComponent.class);
        assertNotNull(EntityComponentRegistry.INSTANCE.get("EXTRA"));
        
        EntityComponentRegistry.INSTANCE.resetRegistry();
        
        assertNull(EntityComponentRegistry.INSTANCE.get("EXTRA"));
        assertEquals(CollisionComponent.class, EntityComponentRegistry.INSTANCE.get(EntityComponentType.COLLISION.name()));
    }
    
    @Test
    void getReturnsNull_whenUnregistered() {
        assertNull(EntityComponentRegistry.INSTANCE.get("NON_EXISTENT_TYPE"));
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
        
        EntityComponentRegistry.INSTANCE.register("POSITION", AltPositionComponent.class);
        assertEquals(AltPositionComponent.class, EntityComponentRegistry.INSTANCE.get("POSITION"));
    }
    
}
