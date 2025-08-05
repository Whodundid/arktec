package com.whodundid.artifactRun.game.data.entity;

import com.whodundid.artifactRun.game.component.AbstractComponent;

public abstract class AbstractEntityComponent extends AbstractComponent<EntityComponentType> {
    
    //==============
    // Constructors
    //==============
    
    protected AbstractEntityComponent(EntityComponentType type) {
        super(type);
    }
    
    //===========
    // Abstracts
    //===========
    
    @Override
    /** @return Creates a copy of this component. */
    public abstract AbstractEntityComponent copy();
    
}
