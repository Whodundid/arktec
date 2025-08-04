package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.ecs.EntityComponentType;

public class VelocityComponentTest {

    @Test
    void defaultConstructor_initializesToZero() {
        var c = new VelocityComponent();
        assertEquals(0f, c.vx);
        assertEquals(0f, c.vy);
    }

    @Test
    void parameterizedConstructor_setsVelocityCorrectly() {
        var c = new VelocityComponent(5f, -3f);
        assertEquals(5f, c.vx);
        assertEquals(-3f, c.vy);
    }

    @Test
    void copyConstructor_copiesValues() {
        var original = new VelocityComponent(1f, 2f);
        var copy = new VelocityComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.vx, copy.vx);
        assertEquals(original.vy, copy.vy);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new VelocityComponent(4f, 6f);
        var copy = c.copy();
        assertTrue(copy instanceof VelocityComponent);
        assertNotSame(c, copy);
        assertEquals(4f, ((VelocityComponent) copy).vx);
        assertEquals(6f, ((VelocityComponent) copy).vy);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.VELOCITY, new VelocityComponent().getComponentType());
    }
    
}