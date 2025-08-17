package com.whodundid.artifactRun.game.data.tile.components;

import com.whodundid.artifactRun.game.data.tile.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.data.tile.WorldTileComponentType;

public class MovementSpeedModifierComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.MOVEMENT_SPEED_MODIFIER;
    
    //========
    // Fields
    //========
    
    public float speedMultiplier = 1.0f;
    
    //==============
    // Constructors
    //==============
    
    public MovementSpeedModifierComponent() { this(1.0f); }
    public MovementSpeedModifierComponent(float multiplier) {
        super(COMPONENT_TYPE);
        
        this.speedMultiplier = multiplier;
    }
    
    public MovementSpeedModifierComponent(MovementSpeedModifierComponent comp) {
        super(COMPONENT_TYPE);
        
        this.speedMultiplier = comp.speedMultiplier;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public MovementSpeedModifierComponent copy() {
        return new MovementSpeedModifierComponent(this);
    }
    
}
