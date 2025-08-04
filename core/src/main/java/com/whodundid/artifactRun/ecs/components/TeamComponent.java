package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.IEntityComponent;

public class TeamComponent implements IEntityComponent {
    
    //================
    // Static Classes
    //================
    
    public static enum Team {
        PLAYER,
        ENEMY,
        NEUTRAL
    }
    
    //========
    // Fields
    //========
    
    public Team team = Team.NEUTRAL;
    
    //==============
    // Constructors
    //==============
    
    public TeamComponent() {}
    public TeamComponent(Team team) {
        this.team = team;
    }
    
    public TeamComponent(TeamComponent comp) {
        this.team = comp.team;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "team";
    }
    
    @Override
    public IEntityComponent copy() {
        return new TeamComponent(this);
    }
    
}
