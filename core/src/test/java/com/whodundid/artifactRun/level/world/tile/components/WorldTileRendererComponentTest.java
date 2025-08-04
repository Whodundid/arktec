package com.whodundid.artifactRun.level.world.tile.components;

import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.level.world.tile.util.TileAnimationMode;

public class WorldTileRendererComponentTest {

    @Test
    void defaultConstructor_setsMinimalFields() {
        var c = new WorldTileRendererComponent("tile_dirt");

        assertEquals("tile_dirt", c.defaultSpriteId);
        assertEquals("DEFAULT", c.startingState);
        assertEquals(TileAnimationMode.NONE, c.animationMode);
        assertEquals(0.0f, c.frameDuration);
        assertTrue(c.animationFrames.isEmpty());
    }

    @Test
    void fullConstructor_setsAllFields() {
        Map<String, List<String>> frames = Map.of(
            "GLOWING", List.of("glow1", "glow2", "glow3"),
            "DEFAULT", List.of("idle1")
        );

        var c = new WorldTileRendererComponent(
            "tile_crystal",
            "GLOWING",
            TileAnimationMode.RANDOM,
            true,
            0.1f,
            1.0f,
            2.0f,
            frames
        );

        assertEquals("tile_crystal", c.defaultSpriteId);
        assertEquals("GLOWING", c.startingState);
        assertEquals(TileAnimationMode.RANDOM, c.animationMode);
        assertTrue(c.looping);
        assertEquals(0.1f, c.frameDuration);
        assertEquals(1.0f, c.minTimeBetweenStates);
        assertEquals(2.0f, c.maxTimeBetweenStates);
        assertEquals(frames.keySet(), c.animationFrames.keySet());
    }

    @Test
    void animationFrames_areDeepCopied() {
        List<String> original = new ArrayList<>(List.of("frame1", "frame2"));
        Map<String, List<String>> anims = Map.of("DEFAULT", original);

        var c = new WorldTileRendererComponent(
            "tile_static", "DEFAULT", TileAnimationMode.SEQUENTIAL,
            false, 0.2f, 0.5f, 1.5f, anims
        );

        original.add("frame3");

        assertEquals(2, c.animationFrames.get("DEFAULT").size());
        assertFalse(c.animationFrames.get("DEFAULT").contains("frame3"));
    }

    @Test
    void copyConstructor_copiesCorrectly() {
        var original = new WorldTileRendererComponent(
            "tile_test", "DEFAULT", TileAnimationMode.SEQUENTIAL,
            true, 0.2f, 1.0f, 3.0f,
            Map.of("DEFAULT", List.of("a", "b", "c"))
        );

        var copy = new WorldTileRendererComponent(original);

        assertEquals(original.defaultSpriteId, copy.defaultSpriteId);
        assertEquals(original.startingState, copy.startingState);
        assertEquals(original.animationMode, copy.animationMode);
        assertEquals(original.looping, copy.looping);
        assertEquals(original.frameDuration, copy.frameDuration);
        assertEquals(original.animationFrames, copy.animationFrames);
        assertNotSame(original.animationFrames.get("DEFAULT"), copy.animationFrames.get("DEFAULT"));
    }

    @Test
    void copyMethod_returnsEqualCopy() {
        var original = new WorldTileRendererComponent("stone");
        var copy = original.copy();

        assertEquals(original.defaultSpriteId, copy.defaultSpriteId);
        assertEquals(original.getComponentType(), copy.getComponentType());
        assertNotSame(original, copy);
    }

    @Test
    void invalidMinMaxTime_clampsCorrectly() {
        var c = new WorldTileRendererComponent(
            "wacky", "DEFAULT", TileAnimationMode.RANDOM,
            false, 0.1f, 3.0f, 1.0f,
            Map.of()
        );

        assertTrue(c.minTimeBetweenStates <= c.maxTimeBetweenStates);
    }
    
}
