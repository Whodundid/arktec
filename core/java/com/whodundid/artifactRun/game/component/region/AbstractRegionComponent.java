package com.whodundid.artifactRun.game.component.region;

import com.whodundid.artifactRun.game.component.AbstractComponent;

public abstract class AbstractRegionComponent extends AbstractComponent<RegionComponentType> {
    
    //==============
    // Constructors
    //==============
    
    protected AbstractRegionComponent(RegionComponentType type) {
        super(type);
    }
    
    //===========
    // Abstracts
    //===========
    
    @Override
    /** @return Creates a copy of this component. */
    public abstract AbstractRegionComponent copy();
    
}
