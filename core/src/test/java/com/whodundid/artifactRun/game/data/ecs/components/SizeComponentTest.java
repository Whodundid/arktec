package com.whodundid.artifactRun.game.data.ecs.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.ecs.util.EntityComponentType;

public class SizeComponentTest {

    @Test
    void defaultConstructor_initializesToZero() {
        var c = new SizeComponent();
        assertEquals(0f, c.width);
        assertEquals(0f, c.height);
    }

    @Test
    void parameterizedConstructor_setsDimensionsCorrectly() {
        var c = new SizeComponent(32f, 64f);
        assertEquals(32f, c.width);
        assertEquals(64f, c.height);
    }

    @Test
    void copyConstructor_copiesValues() {
        var original = new SizeComponent(16f, 24f);
        var copy = new SizeComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.width, copy.width);
        assertEquals(original.height, copy.height);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new SizeComponent(12f, 18f);
        var copy = c.copy();
        assertTrue(copy instanceof SizeComponent);
        assertNotSame(c, copy);
        assertEquals(12f, ((SizeComponent) copy).width);
        assertEquals(18f, ((SizeComponent) copy).height);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.SIZE, new SizeComponent().getComponentType());
    }
    
}