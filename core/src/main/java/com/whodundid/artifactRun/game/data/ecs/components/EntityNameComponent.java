package com.whodundid.artifactRun.game.data.ecs.components;

import com.whodundid.artifactRun.game.data.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.game.data.ecs.util.EntityComponentType;

public class EntityNameComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.NAME;
    
    //========
    // Fields
    //========
    
    public String name;
    
    //==============
    // Constructors
    //==============
    
    public EntityNameComponent(String name) {
        super(COMPONENT_TYPE);
        
        this.name = name;
    }
    
    public EntityNameComponent(EntityNameComponent comp) {
        super(COMPONENT_TYPE);
        
        this.name = comp.name;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public EntityNameComponent copy() {
        return new EntityNameComponent(this);
    }
    
}

