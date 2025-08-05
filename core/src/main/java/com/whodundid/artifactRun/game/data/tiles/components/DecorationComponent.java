package com.whodundid.artifactRun.game.data.tiles.components;

import com.whodundid.artifactRun.game.data.tiles.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.data.tiles.util.WorldTileComponentType;

public class DecorationComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.DECORATION;
    
    //========
    // Fields
    //========
    
    public String decorationId;
    
    //==============
    // Constructors
    //==============
    
    public DecorationComponent(String decorationId) {
        super(COMPONENT_TYPE);
        
        this.decorationId = decorationId;
    }
    
    public DecorationComponent(DecorationComponent comp) {
        super(COMPONENT_TYPE);
        
        this.decorationId = comp.decorationId;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public DecorationComponent copy() {
        return new DecorationComponent(this);
    }
    
}
