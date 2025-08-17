package com.whodundid.artifactRun.game.component.entity.components;

import com.whodundid.artifactRun.game.component.entity.AbstractEntityComponent;
import com.whodundid.artifactRun.game.component.entity.EntityComponentType;

public class PositionComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.POSITION;
    
    //========
    // Fields
    //========
    
    public float x;
    public float y;
    
    //==============
    // Constructors
    //==============
    
    public PositionComponent() { this(0f, 0f); }
    public PositionComponent(float x, float y) {
        super(COMPONENT_TYPE);
        
        this.x = x;
        this.y = y;
    }
    
    public PositionComponent(PositionComponent comp) {
        super(COMPONENT_TYPE);
        
        this.x = comp.x;
        this.y = comp.y;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public PositionComponent copy() {
        return new PositionComponent(this);
    }
    
}
