package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.ecs.EntityComponentType;

public class PositionComponentTest {

    @Test
    void defaultConstructor_initializesAtZero() {
        var c = new PositionComponent();
        assertEquals(0f, c.x);
        assertEquals(0f, c.y);
    }

    @Test
    void parameterizedConstructor_setsPositionCorrectly() {
        var c = new PositionComponent(10f, 20f);
        assertEquals(10f, c.x);
        assertEquals(20f, c.y);
    }

    @Test
    void copyConstructor_copiesValues() {
        var original = new PositionComponent(5f, 15f);
        var copy = new PositionComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.x, copy.x);
        assertEquals(original.y, copy.y);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new PositionComponent(3f, 4f);
        var copy = c.copy();
        assertTrue(copy instanceof PositionComponent);
        assertNotSame(c, copy);
        assertEquals(3f, ((PositionComponent) copy).x);
        assertEquals(4f, ((PositionComponent) copy).y);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.POSITION, new PositionComponent().getComponentType());
    }
    
}