package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.EntityComponentType;

public class LifetimeComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.LIFETIME;
    
    //========
    // Fields
    //========
    
    public float maxLifetime;
    public float timeRemaining;
    
    //==============
    // Constructors
    //==============
    
    public LifetimeComponent(float maxLifetime) { this(maxLifetime, maxLifetime); }
    public LifetimeComponent(float maxLifetime, float timeRemaining) {
        super(COMPONENT_TYPE);
        
        this.maxLifetime = maxLifetime;
        this.timeRemaining = timeRemaining;
    }
    
    public LifetimeComponent(LifetimeComponent comp) {
        super(COMPONENT_TYPE);
        
        this.maxLifetime = comp.maxLifetime;
        this.timeRemaining = comp.timeRemaining;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public LifetimeComponent copy() {
        return new LifetimeComponent(this);
    }
    
}
