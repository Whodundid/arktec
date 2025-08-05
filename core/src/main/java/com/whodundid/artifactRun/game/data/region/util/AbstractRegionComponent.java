package com.whodundid.artifactRun.game.data.region.util;

public abstract class AbstractRegionComponent {
    
    //========
    // Fields
    //========
    
    protected final RegionComponentType componentType;
    
    //==============
    // Constructors
    //==============
    
    protected AbstractRegionComponent(RegionComponentType type) {
        this.componentType = type;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return super.toString() + ":" + getComponentType().name().toLowerCase();
    }
    
    //===========
    // Abstracts
    //===========
    
    /** @return Creates a copy of this component. */
    public abstract AbstractRegionComponent copy();
    
    //=========
    // Getters
    //=========
    
    /** @return The type of this component used for JSON serialization. */
    public RegionComponentType getComponentType() {
        return componentType;
    }
    
}
