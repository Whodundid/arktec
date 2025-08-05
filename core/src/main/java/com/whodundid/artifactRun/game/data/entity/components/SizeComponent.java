package com.whodundid.artifactRun.game.data.entity.components;

import com.whodundid.artifactRun.game.data.entity.AbstractEntityComponent;
import com.whodundid.artifactRun.game.data.entity.EntityComponentType;

public class SizeComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.SIZE;
    
    //========
    // Fields
    //========
    
    public float width;
    public float height;
    
    //==============
    // Constructors
    //==============
    
    public SizeComponent() { this(0f, 0f); }
    public SizeComponent(float width, float height) {
        super(COMPONENT_TYPE);
        
        this.width = width;
        this.height = height;
    }
    
    public SizeComponent(SizeComponent comp) {
        super(COMPONENT_TYPE);
        
        this.width = comp.width;
        this.height = comp.height;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public SizeComponent copy() {
        return new SizeComponent(this);
    }
    
}
