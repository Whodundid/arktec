package com.whodundid.artifactRun.game.data.entity.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.entity.EntityComponentType;

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
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.LIFETIME, new LifetimeComponent(1.0f).getComponentType());
    }
    
}