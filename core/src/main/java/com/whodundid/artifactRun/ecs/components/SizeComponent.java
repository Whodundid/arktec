package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.EntityComponent;

public class SizeComponent implements EntityComponent {
    
    //========
    // Fields
    //========
    
    public float width;
    public float height;
    
    //==============
    // Constructors
    //==============
    
    public SizeComponent() {}
    public SizeComponent(float width, float height) {
        this.width = width;
        this.height = height;
    }
    
    public SizeComponent(SizeComponent comp) {
        this.width = comp.width;
        this.height = comp.height;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "size";
    }
    
    @Override
    public EntityComponent copy() {
        return new SizeComponent(this);
    }
    
}
