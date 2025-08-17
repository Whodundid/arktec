package com.whodundid.artifactRun.game.data.tile.components;

import com.whodundid.artifactRun.game.data.tile.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.data.tile.WorldTileComponentType;

public class TileTypeComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.TILE_TYPE;
    
    //================
    // Static Classes
    //================
    
    public static enum WorldTileType {
        VOID,
        FLOOR,
        WALL
    }
    
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
