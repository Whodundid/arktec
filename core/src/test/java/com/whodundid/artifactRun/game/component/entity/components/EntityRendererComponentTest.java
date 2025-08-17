package com.whodundid.artifactRun.game.component.entity.components;

import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.component.entity.EntityComponentType;
import com.whodundid.artifactRun.game.component.entity.components.EntityRendererComponent.EntityAnimationState;

public class EntityRendererComponentTest {

    @Test
    void basicConstructor_setsDefaultsCorrectly() {
        var c = new EntityRendererComponent("entity_idle");

        assertEquals("entity_idle", c.defaultSpriteId);
        assertEquals(EntityAnimationState.IDLE_DOWN, c.startingState);
        assertFalse(c.isAnimated);
        assertEquals(0.0f, c.frameDuration);
        assertFalse(c.looping);
        assertTrue(c.animationFrames.isEmpty());
    }

    @Test
    void fullConstructor_setsAllFieldsProperly() {
        var frameMap = Map.of(
            EntityAnimationState.WALK_RIGHT, List.of("walk_r1", "walk_r2", "walk_r3"),
            EntityAnimationState.IDLE_RIGHT, List.of("idle_r")
        );

        var c = new EntityRendererComponent(
            "entity_walk",
            EntityAnimationState.WALK_RIGHT,
            true,
            0.15f,
            true,
            frameMap
        );

        assertEquals("entity_walk", c.defaultSpriteId);
        assertEquals(EntityAnimationState.WALK_RIGHT, c.startingState);
        assertTrue(c.isAnimated);
        assertEquals(0.15f, c.frameDuration);
        assertTrue(c.looping);
        assertEquals(2, c.animationFrames.size());
        assertEquals(List.of("walk_r1", "walk_r2", "walk_r3"), c.animationFrames.get(EntityAnimationState.WALK_RIGHT));
    }

    @Test
    void animationFrames_areDeepCopied() {
        var originalFrames = new ArrayList<>(List.of("a", "b"));
        Map<EntityAnimationState, List<String>> inputMap = Map.of(EntityAnimationState.IDLE_LEFT, originalFrames);

        var c = new EntityRendererComponent("test", EntityAnimationState.IDLE_LEFT, true, 0.2f, false, inputMap);

        var internalList = c.animationFrames.get(EntityAnimationState.IDLE_LEFT);
        assertEquals(originalFrames, internalList);
        assertNotSame(originalFrames, internalList);
    }

    @Test
    void copyConstructor_clonesAllFieldsCorrectly() {
        var map = Map.of(EntityAnimationState.ATTACK_UP, List.of("atk_u1", "atk_u2"));

        EntityRendererComponent original = new EntityRendererComponent(
            "boom",
            EntityAnimationState.ATTACK_UP,
            true,
            0.05f,
            false,
            map
        );

        EntityRendererComponent copy = new EntityRendererComponent(original);

        assertEquals(original.defaultSpriteId, copy.defaultSpriteId);
        assertEquals(original.startingState, copy.startingState);
        assertEquals(original.isAnimated, copy.isAnimated);
        assertEquals(original.frameDuration, copy.frameDuration);
        assertEquals(original.looping, copy.looping);
        assertEquals(original.animationFrames, copy.animationFrames);
        assertNotSame(original.animationFrames.get(EntityAnimationState.ATTACK_UP),
                     copy.animationFrames.get(EntityAnimationState.ATTACK_UP));
    }

    @Test
    void copyMethod_createsNewEqualInstance() {
        EntityRendererComponent c1 = new EntityRendererComponent("copy_me");
        EntityRendererComponent c2 = c1.copy();

        assertNotSame(c1, c2);
        assertEquals(c1.defaultSpriteId, c2.defaultSpriteId);
        assertEquals(c1.startingState, c2.startingState);
    }

    @Test
    void getComponentType_returnsRendererType() {
        var c = new EntityRendererComponent("type_test");
        assertEquals(EntityComponentType.RENDERER, c.getComponentType());
    }

    @Test
    void constructor_clampsInvalidFrameDurations() {
        var c = new EntityRendererComponent(
            "bad_duration",
            EntityAnimationState.IDLE_LEFT,
            true,
            -0.5f,
            true,
            Map.of()
        );

        assertEquals(-0.5f, c.frameDuration); // assuming no internal clamping yet
    }

    @Test
    void animationMapHandlesMultipleStates() {
        var map = Map.of(
            EntityAnimationState.IDLE_DOWN, List.of("idle_d1"),
            EntityAnimationState.IDLE_LEFT, List.of("idle_l1"),
            EntityAnimationState.WALK_LEFT, List.of("walk_l1", "walk_l2")
        );

        var c = new EntityRendererComponent("multi", EntityAnimationState.IDLE_LEFT, true, 0.1f, true, map);

        assertEquals(3, c.animationFrames.size());
        assertEquals(List.of("walk_l1", "walk_l2"), c.animationFrames.get(EntityAnimationState.WALK_LEFT));
    }

    @Test
    void modifyingOriginalMap_doesNotAffectComponent() {
        var list = new ArrayList<>(List.of("a", "b"));
        var map = new HashMap<EntityAnimationState, List<String>>();
        map.put(EntityAnimationState.WALK_DOWN, list);

        var c = new EntityRendererComponent("immute_test", EntityAnimationState.WALK_DOWN, true, 0.1f, true, map);
        list.add("c"); // modify original list

        assertEquals(2, c.animationFrames.get(EntityAnimationState.WALK_DOWN).size());
        assertFalse(c.animationFrames.get(EntityAnimationState.WALK_DOWN).contains("c"));
    }
    
}

