package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import com.badlogic.gdx.graphics.g2d.TextureRegion;

public class RenderComponentTest {

    @Test
    void constructor_setsSpriteCorrectly() {
        TextureRegion mockSprite = new TextureRegion();
        var c = new RenderComponent(mockSprite);
        assertEquals(mockSprite, c.sprite);
    }

    @Test
    void copyConstructor_copiesReference() {
        TextureRegion mockSprite = new TextureRegion();
        var original = new RenderComponent(mockSprite);
        var copy = new RenderComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.sprite, copy.sprite);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        TextureRegion mockSprite = new TextureRegion();
        var c = new RenderComponent(mockSprite);
        var copy = c.copy();
        assertTrue(copy instanceof RenderComponent);
        assertNotSame(c, copy);
        assertEquals(mockSprite, ((RenderComponent) copy).sprite);
    }

    @Test
    void getTypeName_returnsCorrectString() {
        TextureRegion mockSprite = new TextureRegion();
        assertEquals("render", new RenderComponent(mockSprite).getTypeName());
    }
    
}