package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.EntityComponent;

public class PositionComponent implements EntityComponent {
    
    //========
    // Fields
    //========
    
    public float x;
    public float y;
    
    //==============
    // Constructors
    //==============
    
    public PositionComponent() {}
    public PositionComponent(float x, float y) {
        this.x = x;
        this.y = y;
    }
    
    public PositionComponent(PositionComponent comp) {
        this.x = comp.x;
        this.y = comp.y;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "position";
    }
    
    @Override
    public EntityComponent copy() {
        return new PositionComponent(this);
    }
    
}
