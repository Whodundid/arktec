package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class CollisionComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.COLLISION;
    
    //========
    // Fields
    //========
    
    public boolean isSolid = true;
    
    //==============
    // Constructors
    //==============
    
    public CollisionComponent() { this(true); }
    public CollisionComponent(boolean isSolid) {
        super(COMPONENT_TYPE);
        
        this.isSolid = isSolid;
    }
    
    public CollisionComponent(CollisionComponent comp) {
        super(COMPONENT_TYPE);
        
        this.isSolid = comp.isSolid;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public CollisionComponent copy() {
        return new CollisionComponent(this);
    }
    
}
