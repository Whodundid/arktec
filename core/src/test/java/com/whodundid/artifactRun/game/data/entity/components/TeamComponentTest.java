package com.whodundid.artifactRun.game.data.entity.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.entity.EntityComponentType;

public class TeamComponentTest {

    @Test
    void defaultConstructor_setsTeamToNeutral() {
        var c = new FactionComponent();
        assertEquals(FactionComponent.FACTION.NEUTRAL, c.faction);
    }

    @Test
    void parameterizedConstructor_setsTeamCorrectly() {
        var c = new FactionComponent(FactionComponent.FACTION.PLAYER);
        assertEquals(FactionComponent.FACTION.PLAYER, c.faction);
    }

    @Test
    void copyConstructor_copiesValue() {
        var original = new FactionComponent(FactionComponent.FACTION.ENEMY);
        var copy = new FactionComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.faction, copy.faction);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new FactionComponent(FactionComponent.FACTION.PLAYER);
        var copy = c.copy();
        assertTrue(copy instanceof FactionComponent);
        assertNotSame(c, copy);
        assertEquals(FactionComponent.FACTION.PLAYER, ((FactionComponent) copy).faction);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.FACTION, new FactionComponent().getComponentType());
    }
    
}