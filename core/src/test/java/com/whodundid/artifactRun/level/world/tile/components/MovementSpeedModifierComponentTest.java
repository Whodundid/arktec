package com.whodundid.artifactRun.level.world.tile.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

public class MovementSpeedModifierComponentTest {

    @Test
    void defaultConstructor_setsDefaultValue() {
        var c = new MovementSpeedModifierComponent();
        assertEquals(1.0f, c.speedMultiplier);
    }

    @Test
    void customConstructor_setsMultiplier() {
        var c = new MovementSpeedModifierComponent(0.8f);
        assertEquals(0.8f, c.speedMultiplier);
    }

    @Test
    void copyConstructor_copiesCorrectly() {
        var c1 = new MovementSpeedModifierComponent(1.25f);
        var c2 = new MovementSpeedModifierComponent(c1);
        assertEquals(1.25f, c2.speedMultiplier);
    }

    @Test
    void copyMethod_producesEqualCopy() {
        var c = new MovementSpeedModifierComponent(1.5f);
        var copy = c.copy();
        assertEquals(1.5f, copy.speedMultiplier);
    }
    
}
