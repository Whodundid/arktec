package com.whodundid.artifactRun.world;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.world.components.*;
import com.whodundid.artifactRun.world.util.TileAnimationMode;
import com.whodundid.artifactRun.world.util.WorldTileType;

public class WorldTileTest {

    @Test
    void testTileIdIsGenerated() {
        WorldTile tile = new WorldTile();
        assertNotNull(tile.getTileId());
    }

    @Test
    void testAddAndGetComponent() {
        WorldTile tile = new WorldTile();
        tile.addComponent(new TileTypeComponent(WorldTileType.FLOOR));

        TileTypeComponent type = tile.getComponent(TileTypeComponent.class);
        assertNotNull(type);
        assertEquals(WorldTileType.FLOOR, type.type);
    }

    @Test
    void testHasComponentByClassAndName() {
        WorldTile tile = new WorldTile();
        tile.componentTypeMap.put("TILE_TYPE", TileTypeComponent.class);
        tile.addComponent(new TileTypeComponent(WorldTileType.WALL));

        assertTrue(tile.hasComponent(TileTypeComponent.class));
        assertTrue(tile.hasComponent("TILE_TYPE"));
    }

    @Test
    void testRemoveComponentWorks() {
        WorldTile tile = new WorldTile();
        tile.addComponent(new DecorationComponent("test_decoration"));
        assertTrue(tile.hasComponent(DecorationComponent.class));

        tile.removeComponent(DecorationComponent.class);
        assertFalse(tile.hasComponent(DecorationComponent.class));
    }

    @Test
    void testComponentOverwrite() {
        WorldTile tile = new WorldTile();
        tile.addComponent(new VisionModifierComponent(1.0f));
        tile.addComponent(new VisionModifierComponent(0.5f));

        VisionModifierComponent vision = tile.getComponent(VisionModifierComponent.class);
        assertEquals(0.5f, vision.visibilityMultiplier);
    }

    @Test
    void testCopyConstructorCreatesNewIdAndCopiesComponents() {
        WorldTile original = new WorldTile();
        original.addComponent(new TileTypeComponent(WorldTileType.FLOOR));
        original.addComponent(new MovementSpeedModifierComponent(0.8f));

        WorldTile copy = new WorldTile(original);

        assertNotEquals(original.getTileId(), copy.getTileId());

        TileTypeComponent originalType = original.getComponent(TileTypeComponent.class);
        TileTypeComponent copiedType = copy.getComponent(TileTypeComponent.class);
        assertNotSame(originalType, copiedType);
        assertEquals(originalType.type, copiedType.type);
    }

    @Test
    void testToJsonAndFromJson() {
        WorldTile tile = new WorldTile();
        tile.componentTypeMap.put("DAMAGE", DamageComponent.class);
        tile.addComponent(new DamageComponent(5, 1.0f));

        String json = tile.toJson();
        WorldTile loaded = WorldTile.fromJson(json);
        loaded.componentTypeMap.put("DAMAGE", DamageComponent.class); // re-link

        DamageComponent dmg = loaded.getComponent(DamageComponent.class);
        assertNotNull(dmg);
        assertEquals(5, dmg.damageAmount);
        assertEquals(1.0f, dmg.damageCooldown);
    }

    @Test
    void testAnimationComponentSerialization() {
        Map<String, List<String>> frames = Map.of("FLICKER", List.of("f1", "f2"));
        WorldTileRendererComponent renderer = new WorldTileRendererComponent(
            "glow_tile", "FLICKER", TileAnimationMode.RANDOM,
            true, 0.2f, 1.0f, 2.0f, frames
        );

        WorldTile tile = new WorldTile();
        tile.componentTypeMap.put("RENDERER", WorldTileRendererComponent.class);
        tile.addComponent(renderer);

        String json = tile.toJson();
        WorldTile restored = WorldTile.fromJson(json);
        restored.componentTypeMap.put("RENDERER", WorldTileRendererComponent.class);

        WorldTileRendererComponent result = restored.getComponent(WorldTileRendererComponent.class);
        assertEquals("glow_tile", result.defaultSpriteId);
        assertEquals(TileAnimationMode.RANDOM, result.animationMode);
        assertEquals(List.of("f1", "f2"), result.animationFrames.get("FLICKER"));
    }

    @Test
    void testNullComponentNotAdded() {
        WorldTile tile = new WorldTile();
        tile.addComponent(null);
        assertTrue(tile.getComponentList().isEmpty());
    }

    @Test
    void testComponentMapReflectsComponentList() {
        WorldTile tile = new WorldTile();
        tile.addComponent(new MovementSpeedModifierComponent(1.5f));
        tile.buildComponentMap();

        assertTrue(tile.getComponentMap().containsKey(MovementSpeedModifierComponent.class));
    }

    @Test
    void testGetComponentByInvalidNameReturnsNullSafely() {
        WorldTile tile = new WorldTile();
        assertNull(tile.getComponent("NOT_A_REAL_TYPE"));
    }

    @Test
    void testGetComponentByTypeNameMismatchReturnsNull() {
        WorldTile tile = new WorldTile();
        tile.componentTypeMap.put("SOMETHING_WRONG", DecorationComponent.class);
        tile.addComponent(new DecorationComponent("bad"));

        assertNull(tile.getComponent("SOMETHING_WRONG")); // name mismatch
    }

    @Test
    void testToStringIsReasonable() {
        WorldTile tile = new WorldTile();
        tile.componentTypeMap.put("FOO", DamageComponent.class);
        tile.addComponent(new DamageComponent(3, 0.5f));

        String out = tile.toString();
        assertTrue(out.contains("WorldTile{id="));
        assertTrue(out.contains("FOO"));
    }
    
}
