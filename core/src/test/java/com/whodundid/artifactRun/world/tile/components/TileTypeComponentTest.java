package com.whodundid.artifactRun.world.tile.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.world.tile.util.WorldTileType;

public class TileTypeComponentTest {

    @Test
    void constructor_setsTileType() {
        var c = new TileTypeComponent(WorldTileType.WALL);
        assertEquals(WorldTileType.WALL, c.type);
    }

    @Test
    void copyConstructor_copiesCorrectly() {
        var original = new TileTypeComponent(WorldTileType.FLOOR);
        var copy = new TileTypeComponent(original);
        assertEquals(WorldTileType.FLOOR, copy.type);
    }

    @Test
    void copyMethod_returnsEqualInstance() {
        var c = new TileTypeComponent(WorldTileType.VOID);
        var copy = c.copy();
        assertEquals(WorldTileType.VOID, copy.type);
        assertNotSame(c, copy);
    }
    
}
