package com.whodundid.artifactRun.game.data.tiles.util;

public abstract class AbstractWorldTileComponent {
    
    //========
    // Fields
    //========
    
    protected final WorldTileComponentType componentType;
    
    //==============
    // Constructors
    //==============
    
    protected AbstractWorldTileComponent(WorldTileComponentType type) {
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
    
    /** @return Creates a copy of this world tile component. */
    public abstract AbstractWorldTileComponent copy();
    
    //=========
    // Getters
    //=========
    
    /** @return The type of this component used for JSON serialization. */
    public WorldTileComponentType getComponentType() {
        return componentType;
    }
    
}
