package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.IEntityComponent;

public class VelocityComponent implements IEntityComponent {
    
    //========
    // Fields
    //========
    
    public transient float vx;
    public transient float vy;
    
    //==============
    // Constructors
    //==============
    
    public VelocityComponent() {}
    public VelocityComponent(float vx, float vy) {
        this.vx = vx;
        this.vy = vy;
    }
    
    public VelocityComponent(VelocityComponent comp) {
        this.vx = comp.vx;
        this.vy = comp.vy;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "velocity";
    }
    
    @Override
    public IEntityComponent copy() {
        return new VelocityComponent(this);
    }
    
}
