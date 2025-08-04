package com.whodundid.artifactRun.level.world.tile.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

public class DamageComponentTest {

    @Test
    void defaultConstructor_setsZeroDamage() {
        var c = new DamageComponent();
        assertEquals(0, c.damageAmount);
        assertEquals(0.0f, c.damageCooldown);
    }

    @Test
    void constructor_setsFields() {
        var c = new DamageComponent(10, 1.5f);
        assertEquals(10, c.damageAmount);
        assertEquals(1.5f, c.damageCooldown);
    }

    @Test
    void copyConstructor_copiesCorrectly() {
        var original = new DamageComponent(5, 2.0f);
        var copy = new DamageComponent(original);

        assertEquals(original.damageAmount, copy.damageAmount);
        assertEquals(original.damageCooldown, copy.damageCooldown);
    }

    @Test
    void copyMethod_returnsCopy() {
        var c = new DamageComponent(3, 0.75f);
        var copy = c.copy();

        assertNotSame(c, copy);
        assertEquals(3, copy.damageAmount);
    }
    
}
