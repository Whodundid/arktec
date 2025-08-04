package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class InputComponentTest {

    @Test
    void defaultConstructor_initializesWithAllFalse() {
        var c = new InputComponent();
        assertFalse(c.up);
        assertFalse(c.down);
        assertFalse(c.left);
        assertFalse(c.right);
        assertFalse(c.shoot);
    }

    @Test
    void parameterizedConstructor_setsValuesCorrectly() {
        var c = new InputComponent(true, false, true, false, true);
        assertTrue(c.up);
        assertFalse(c.down);
        assertTrue(c.left);
        assertFalse(c.right);
        assertTrue(c.shoot);
    }

    @Test
    void copyConstructor_copiesValues() {
        var original = new InputComponent(true, true, false, true, false);
        var copy = new InputComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.up, copy.up);
        assertEquals(original.down, copy.down);
        assertEquals(original.left, copy.left);
        assertEquals(original.right, copy.right);
        assertEquals(original.shoot, copy.shoot);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new InputComponent(true, false, true, true, false);
        var copy = c.copy();
        assertTrue(copy instanceof InputComponent);
        assertNotSame(c, copy);
        var i = (InputComponent) copy;
        assertEquals(c.up, i.up);
        assertEquals(c.down, i.down);
        assertEquals(c.left, i.left);
        assertEquals(c.right, i.right);
        assertEquals(c.shoot, i.shoot);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.INPUT, new InputComponent().getComponentType());
    }
    
}