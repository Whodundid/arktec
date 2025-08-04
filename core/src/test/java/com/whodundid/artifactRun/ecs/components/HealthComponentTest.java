package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

public class HealthComponentTest {

    @Test
    void defaultConstructor_initializesWithZeroHealth() {
        var c = new HealthComponent();
        assertEquals(0, c.health);
        assertEquals(0, c.maxHealth);
    }

    @Test
    void parameterizedConstructor_setsFieldsCorrectly() {
        var c = new HealthComponent(50, 100);
        assertEquals(50, c.health);
        assertEquals(100, c.maxHealth);
    }

    @Test
    void copyConstructor_copiesValues() {
        var original = new HealthComponent(75, 100);
        var copy = new HealthComponent(original);

        assertNotSame(original, copy);
        assertEquals(original.health, copy.health);
        assertEquals(original.maxHealth, copy.maxHealth);
    }

    @Test
    void copyMethod_returnsNewInstanceWithSameValues() {
        var c = new HealthComponent(10, 20);
        var copy = c.copy();

        assertTrue(copy instanceof HealthComponent);
        assertNotSame(c, copy);

        var h = (HealthComponent) copy;
        assertEquals(10, h.health);
        assertEquals(20, h.maxHealth);
    }

    @Test
    void getTypeName_returnsCorrectString() {
        assertEquals("health", new HealthComponent().getTypeName());
    }
    
}
