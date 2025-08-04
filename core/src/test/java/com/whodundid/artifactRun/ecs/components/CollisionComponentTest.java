package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class CollisionComponentTest {

    @Test
    void defaultConstructor_isSolidByDefault() {
        var c = new CollisionComponent();
        assertTrue(c.isSolid);
    }

    @Test
    void parameterizedConstructor_setsCorrectValue() {
        var c = new CollisionComponent(false);
        assertFalse(c.isSolid);
    }

    @Test
    void copyConstructor_copiesValue() {
        var original = new CollisionComponent(false);
        var copy = new CollisionComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.isSolid, copy.isSolid);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new CollisionComponent(false);
        var copy = c.copy();
        assertTrue(copy instanceof CollisionComponent);
        assertNotSame(c, copy);
        assertEquals(false, ((CollisionComponent) copy).isSolid);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.COLLISION, new CollisionComponent().getComponentType());
    }
    
}