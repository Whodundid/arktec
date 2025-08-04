package com.whodundid.artifactRun.ecs;

import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public abstract class AbstractEntityComponent {
    
    //========
    // Fields
    //========
    
    protected final EntityComponentType componentType;
    
    //==============
    // Constructors
    //==============
    
    protected AbstractEntityComponent(EntityComponentType type) {
        this.componentType = type;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return getComponentType().name().toLowerCase();
    }
    
    //===========
    // Abstracts
    //===========
    
    /** @return Creates a copy of this component. */
    public abstract AbstractEntityComponent copy();
    
    //=========
    // Getters
    //=========
    
    /** @return The type of this component used for JSON serialization. */
    public EntityComponentType getComponentType() {
        return componentType;
    }
    
}
