package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class TeamComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.TEAM;
    
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
    
    public Team team;
    
    //==============
    // Constructors
    //==============
    
    public TeamComponent() { this(Team.NEUTRAL); }
    public TeamComponent(Team team) {
        super(COMPONENT_TYPE);
        
        this.team = team;
    }
    
    public TeamComponent(TeamComponent comp) {
        super(COMPONENT_TYPE);
        
        this.team = comp.team;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public TeamComponent copy() {
        return new TeamComponent(this);
    }
    
}
