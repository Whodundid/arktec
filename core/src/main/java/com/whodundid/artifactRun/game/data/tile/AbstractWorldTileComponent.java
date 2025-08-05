package com.whodundid.artifactRun.game.data.tile;

import com.whodundid.artifactRun.game.data.component.AbstractComponent;

public abstract class AbstractWorldTileComponent extends AbstractComponent<WorldTileComponentType> {
    
    //==============
    // Constructors
    //==============
    
    protected AbstractWorldTileComponent(WorldTileComponentType type) {
        super(type);
    }
    
    //===========
    // Abstracts
    //===========
    
    @Override
    /** @return Creates a copy of this component. */
    public abstract AbstractWorldTileComponent copy();
    
}
