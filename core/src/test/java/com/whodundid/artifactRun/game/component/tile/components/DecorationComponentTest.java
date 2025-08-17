package com.whodundid.artifactRun.game.component.tile.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

public class DecorationComponentTest {

    @Test
    void constructor_setsDecorationIdCorrectly() {
        var c = new DecorationComponent("tree_oak");
        assertEquals("tree_oak", c.decorationId);
    }

    @Test
    void copyConstructor_copiesCorrectly() {
        var original = new DecorationComponent("torch");
        var copy = new DecorationComponent(original);

        assertEquals("torch", copy.decorationId);
        assertNotSame(original, copy);
    }

    @Test
    void copyMethod_returnsNewCopy() {
        var c = new DecorationComponent("vase");
        var copy = c.copy();

        assertNotSame(c, copy);
        assertEquals("vase", copy.decorationId);
    }
    
}
