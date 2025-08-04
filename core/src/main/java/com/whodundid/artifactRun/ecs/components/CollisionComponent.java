package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.IEntityComponent;

public class CollisionComponent implements IEntityComponent {
    
    //========
    // Fields
    //========
    
    public boolean isSolid = true;
    
    //==============
    // Constructors
    //==============
    
    public CollisionComponent() {}
    public CollisionComponent(boolean isSolid) {
        this.isSolid = isSolid;
    }
    
    public CollisionComponent(CollisionComponent comp) {
        this.isSolid = comp.isSolid;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "collision";
    }
    
    @Override
    public IEntityComponent copy() {
        return new CollisionComponent(this);
    }
    
}
