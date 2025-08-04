package com.whodundid.artifactRun.world.tile.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

public class VisionModifierComponentTest {

    @Test
    void defaultConstructor_setsOneMultiplier() {
        var c = new VisionModifierComponent();
        assertEquals(1.0f, c.visibilityMultiplier);
    }

    @Test
    void customConstructor_setsCorrectMultiplier() {
        var c = new VisionModifierComponent(0.5f);
        assertEquals(0.5f, c.visibilityMultiplier);
    }

    @Test
    void copyConstructor_worksCorrectly() {
        var c1 = new VisionModifierComponent(0.25f);
        var c2 = new VisionModifierComponent(c1);

        assertEquals(0.25f, c2.visibilityMultiplier);
    }

    @Test
    void copyMethod_producesEqualComponent() {
        var c = new VisionModifierComponent(2.0f);
        var copy = c.copy();

        assertEquals(2.0f, copy.visibilityMultiplier);
        assertNotSame(c, copy);
    }
    
}
