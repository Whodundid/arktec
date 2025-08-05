package com.whodundid.artifactRun.game.data.ecs.components;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.game.data.ecs.util.EntityComponentType;

public class TeamComponentTest {

    @Test
    void defaultConstructor_setsTeamToNeutral() {
        var c = new TeamComponent();
        assertEquals(TeamComponent.Team.NEUTRAL, c.team);
    }

    @Test
    void parameterizedConstructor_setsTeamCorrectly() {
        var c = new TeamComponent(TeamComponent.Team.PLAYER);
        assertEquals(TeamComponent.Team.PLAYER, c.team);
    }

    @Test
    void copyConstructor_copiesValue() {
        var original = new TeamComponent(TeamComponent.Team.ENEMY);
        var copy = new TeamComponent(original);
        assertNotSame(original, copy);
        assertEquals(original.team, copy.team);
    }

    @Test
    void copyMethod_returnsNewInstance() {
        var c = new TeamComponent(TeamComponent.Team.PLAYER);
        var copy = c.copy();
        assertTrue(copy instanceof TeamComponent);
        assertNotSame(c, copy);
        assertEquals(TeamComponent.Team.PLAYER, ((TeamComponent) copy).team);
    }

    @Test
    void getTypeName_returnsCorrectComponetType() {
        assertEquals(EntityComponentType.TEAM, new TeamComponent().getComponentType());
    }
    
}