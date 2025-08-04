package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.IEntityComponent;

public class LifetimeComponent implements IEntityComponent {
    
    //========
    // Fields
    //========
    
    public float maxLifetime;
    public float timeRemaining;
    
    //==============
    // Constructors
    //==============
    
    public LifetimeComponent(float maxLifetime) {
        this.maxLifetime = maxLifetime;
        this.timeRemaining = maxLifetime;
    }
    
    public LifetimeComponent(float maxLifetime, float timeRemaining) {
        this.maxLifetime = maxLifetime;
        this.timeRemaining = timeRemaining;
    }
    
    public LifetimeComponent(LifetimeComponent comp) {
        this.maxLifetime = comp.maxLifetime;
        this.timeRemaining = comp.timeRemaining;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "lifetime";
    }
    
    @Override
    public IEntityComponent copy() {
        return new LifetimeComponent(this);
    }
    
}
