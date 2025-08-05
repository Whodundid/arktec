package com.whodundid.artifactRun.game.data.ecs.components;

import com.whodundid.artifactRun.game.data.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.game.data.ecs.util.EntityComponentType;

public class FactionComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.FACTION;
    
    //================
    // Static Classes
    //================
    
    public static enum FACTION {
        PLAYER,
        ENEMY,
        NEUTRAL
    }
    
    //========
    // Fields
    //========
    
    public FACTION faction;
    
    //==============
    // Constructors
    //==============
    
    public FactionComponent() { this(FACTION.NEUTRAL); }
    public FactionComponent(FACTION team) {
        super(COMPONENT_TYPE);
        
        this.faction = team;
    }
    
    public FactionComponent(FactionComponent comp) {
        super(COMPONENT_TYPE);
        
        this.faction = comp.faction;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public FactionComponent copy() {
        return new FactionComponent(this);
    }
    
}
