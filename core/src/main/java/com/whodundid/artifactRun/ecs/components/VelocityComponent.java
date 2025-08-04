package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class VelocityComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.VELOCITY;
    
    //========
    // Fields
    //========
    
    public transient float vx;
    public transient float vy;
    
    //==============
    // Constructors
    //==============
    
    public VelocityComponent() { this(0f, 0f); }
    public VelocityComponent(float vx, float vy) {
        super(COMPONENT_TYPE);
        
        this.vx = vx;
        this.vy = vy;
    }
    
    public VelocityComponent(VelocityComponent comp) {
        super(COMPONENT_TYPE);
        
        this.vx = comp.vx;
        this.vy = comp.vy;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public VelocityComponent copy() {
        return new VelocityComponent(this);
    }
    
}
