package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

public class LifetimeComponentTest {

    @Test
    void constructor_setsTimeRemainingCorrectly() {
        var c = new LifetimeComponent(5.0f);
        assertEquals(5.0f, c.timeRemaining);
    }

    @Test
    void copyConstructor_copiesValue() {
        var original = new LifetimeComponent(3.5f);
        var copy = new LifetimeComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.timeRemaining, copy.timeRemaining);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new LifetimeComponent(2.5f);
        var copy = c.copy();
        assertTrue(copy instanceof LifetimeComponent);
        assertNotSame(c, copy);
        assertEquals(2.5f, ((LifetimeComponent) copy).timeRemaining);
    }

    @Test
    void getTypeName_returnsCorrectString() {
        assertEquals("lifetime", new LifetimeComponent(1.0f).getTypeName());
    }
    
}