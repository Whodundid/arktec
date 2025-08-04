package com.whodundid.artifactRun.level.world.tile;

import static org.junit.jupiter.api.Assertions.*;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.level.world.tile.components.DecorationComponent;
import com.whodundid.artifactRun.level.world.tile.components.MovementSpeedModifierComponent;
import com.whodundid.artifactRun.level.world.tile.components.TileTypeComponent;
import com.whodundid.artifactRun.level.world.tile.components.VisionModifierComponent;
import com.whodundid.artifactRun.level.world.tile.components.WorldTileRendererComponent;
import com.whodundid.artifactRun.level.world.tile.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.level.world.tile.util.WorldTileComponentType;

public class WorldTileComponentRegistryTest {
    
    @BeforeEach
    void setup() {
        WorldTileComponentRegistry.resetRegistry();
    }
    
    @Test
    void defaultComponents_areRegistered() {
        assertEquals(DecorationComponent.class, WorldTileComponentRegistry.get(WorldTileComponentType.DECORATION.name()));
        assertEquals(TileTypeComponent.class, WorldTileComponentRegistry.get(WorldTileComponentType.TILE_TYPE.name()));
    }
    
    @Test
    void canRegisterComponent_byEnum() {
        WorldTileComponentRegistry.register(WorldTileComponentType.VISION_MODIFIER, VisionModifierComponent.class);
        String expected = WorldTileComponentType.VISION_MODIFIER.name();
        assertEquals(VisionModifierComponent.class, WorldTileComponentRegistry.get(expected));
    }
    
    @Test
    void canRegisterComponent_byString() {
        String id = "DYNAMIC_" + UUID.randomUUID();
        class DummyComponent extends AbstractWorldTileComponent {
            DummyComponent() { super(WorldTileComponentType.DECORATION); }
            @Override public AbstractWorldTileComponent copy() { return new DummyComponent(); }
        }
        
        WorldTileComponentRegistry.register(id, DummyComponent.class);
        assertEquals(DummyComponent.class, WorldTileComponentRegistry.get(id));
    }
    
    @Test
    void unknownType_returnsNull() {
        assertNull(WorldTileComponentRegistry.get("NO_SUCH_COMPONENT"));
    }
    
    @Test
    void register_overwritesComponentType() {
        class DummyA extends AbstractWorldTileComponent {
            DummyA() {
                super(WorldTileComponentType.DAMAGE);
            }
            public AbstractWorldTileComponent copy() {
                return new DummyA();
            }
        }
        class DummyB extends AbstractWorldTileComponent {
            DummyB() {
                super(WorldTileComponentType.DAMAGE);
            }
            public AbstractWorldTileComponent copy() {
                return new DummyB();
            }
        }
        
        WorldTileComponentRegistry.register(WorldTileComponentType.DAMAGE, DummyA.class);
        WorldTileComponentRegistry.register(WorldTileComponentType.DAMAGE, DummyB.class);
        
        assertEquals(DummyB.class, WorldTileComponentRegistry.get("DAMAGE"));
    }
    
    @Test
    void resetRegistry_clearsCustomTypes_andRestoresDefaults() {
        WorldTileComponentRegistry.register("CUSTOM", MovementSpeedModifierComponent.class);
        assertNotNull(WorldTileComponentRegistry.get("CUSTOM"));
        
        WorldTileComponentRegistry.resetRegistry();
        
        assertNull(WorldTileComponentRegistry.get("CUSTOM"));
        assertEquals(WorldTileRendererComponent.class, WorldTileComponentRegistry.get(WorldTileComponentType.RENDERER.name()));
    }
    
}
