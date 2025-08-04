package com.whodundid.artifactRun.ecs.components;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class EntityRendererComponentTest {

    @Test
    void constructor_setsSpriteCorrectly() {
        TextureRegion mockSprite = new TextureRegion();
        var c = new EntityRendererComponent(mockSprite);
        assertEquals(mockSprite, c.sprite);
    }

    @Test
    void copyConstructor_copiesReference() {
        TextureRegion mockSprite = new TextureRegion();
        var original = new EntityRendererComponent(mockSprite);
        var copy = new EntityRendererComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.sprite, copy.sprite);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        TextureRegion mockSprite = new TextureRegion();
        var c = new EntityRendererComponent(mockSprite);
        var copy = c.copy();
        assertTrue(copy instanceof EntityRendererComponent);
        assertNotSame(c, copy);
        assertEquals(mockSprite, ((EntityRendererComponent) copy).sprite);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        TextureRegion mockSprite = new TextureRegion();
        assertEquals(EntityComponentType.RENDERER, new EntityRendererComponent(mockSprite).getComponentType());
    }
    
}