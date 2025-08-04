package com.whodundid.artifactRun.world.components;

import com.whodundid.artifactRun.world.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.world.util.WorldTileComponentType;
import com.whodundid.artifactRun.world.util.WorldTileType;

public class TileTypeComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.TILE_TYPE;
    
    //========
    // Fields
    //========
    
    public WorldTileType type;
    
    //==============
    // Constructors
    //==============
    
    public TileTypeComponent(WorldTileType type) {
        super(COMPONENT_TYPE);
        
        this.type = type;
    }
    
    public TileTypeComponent(TileTypeComponent comp) {
        super(COMPONENT_TYPE);
        
        this.type = comp.type;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public TileTypeComponent copy() {
        return new TileTypeComponent(this);
    }
    
}
