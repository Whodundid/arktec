package com.whodundid.artifactRun.game.data.tiles.components;

import com.whodundid.artifactRun.game.data.tiles.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.data.tiles.util.WorldTileComponentType;

public class VisionModifierComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.VISION_MODIFIER;
    
    //========
    // Fields
    //========
    
    public float visibilityMultiplier = 1.0f;
    
    //==============
    // Constructors
    //==============
    
    public VisionModifierComponent() { this(1.0f); }
    public VisionModifierComponent(float multiplier) {
        super(COMPONENT_TYPE);
        
        this.visibilityMultiplier = multiplier;
    }
    
    public VisionModifierComponent(VisionModifierComponent comp) {
        super(COMPONENT_TYPE);
        
        this.visibilityMultiplier = comp.visibilityMultiplier;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public VisionModifierComponent copy() {
        return new VisionModifierComponent(this);
    }
    
}
