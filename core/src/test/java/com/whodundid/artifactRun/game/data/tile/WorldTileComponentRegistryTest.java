package com.whodundid.artifactRun.game.data.tile;

import static org.junit.jupiter.api.Assertions.*;

import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.tile.components.DecorationComponent;
import com.whodundid.artifactRun.game.data.tile.components.MovementSpeedModifierComponent;
import com.whodundid.artifactRun.game.data.tile.components.TileTypeComponent;
import com.whodundid.artifactRun.game.data.tile.components.VisionModifierComponent;
import com.whodundid.artifactRun.game.data.tile.components.WorldTileRendererComponent;

public class WorldTileComponentRegistryTest {
    
    @BeforeEach
    void setup() {
        WorldTileComponentRegistry.INSTANCE.resetRegistry();
    }
    
    @Test
    void defaultComponents_areRegistered() {
        assertEquals(DecorationComponent.class, WorldTileComponentRegistry.INSTANCE.get(WorldTileComponentType.DECORATION.name()));
        assertEquals(TileTypeComponent.class, WorldTileComponentRegistry.INSTANCE.get(WorldTileComponentType.TILE_TYPE.name()));
    }
    
    @Test
    void canRegisterComponent_byEnum() {
        WorldTileComponentRegistry.INSTANCE.register(WorldTileComponentType.VISION_MODIFIER, VisionModifierComponent.class);
        String expected = WorldTileComponentType.VISION_MODIFIER.name();
        assertEquals(VisionModifierComponent.class, WorldTileComponentRegistry.INSTANCE.get(expected));
    }
    
    @Test
    void canRegisterComponent_byString() {
        String id = "DYNAMIC_" + UUID.randomUUID();
        class DummyComponent extends AbstractWorldTileComponent {
            DummyComponent() { super(WorldTileComponentType.DECORATION); }
            @Override public AbstractWorldTileComponent copy() { return new DummyComponent(); }
        }
        
        WorldTileComponentRegistry.INSTANCE.register(id, DummyComponent.class);
        assertEquals(DummyComponent.class, WorldTileComponentRegistry.INSTANCE.get(id));
    }
    
    @Test
    void unknownType_returnsNull() {
        assertNull(WorldTileComponentRegistry.INSTANCE.get("NO_SUCH_COMPONENT"));
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
        
        WorldTileComponentRegistry.INSTANCE.register(WorldTileComponentType.DAMAGE, DummyA.class);
        WorldTileComponentRegistry.INSTANCE.register(WorldTileComponentType.DAMAGE, DummyB.class);
        
        assertEquals(DummyB.class, WorldTileComponentRegistry.INSTANCE.get("DAMAGE"));
    }
    
    @Test
    void resetRegistry_clearsCustomTypes_andRestoresDefaults() {
        WorldTileComponentRegistry.INSTANCE.register("CUSTOM", MovementSpeedModifierComponent.class);
        assertNotNull(WorldTileComponentRegistry.INSTANCE.get("CUSTOM"));
        
        WorldTileComponentRegistry.INSTANCE.resetRegistry();
        
        assertNull(WorldTileComponentRegistry.INSTANCE.get("CUSTOM"));
        assertEquals(WorldTileRendererComponent.class, WorldTileComponentRegistry.INSTANCE.get(WorldTileComponentType.RENDERER.name()));
    }
    
}
