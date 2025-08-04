package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.IEntityComponent;

public class HealthComponent implements IEntityComponent {
    
    //========
    // Fields
    //========
    
    public int maxHealth;
    public int health;
    
    //==============
    // Constructors
    //==============
    
    public HealthComponent() {}
    public HealthComponent(int maxHealth, int health) {
        this.maxHealth = maxHealth;
        this.health = health;
    }
    
    public HealthComponent(HealthComponent comp) {
        this.maxHealth = comp.maxHealth;
        this.health = comp.health;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "health";
    }
    
    @Override
    public IEntityComponent copy() {
        return new HealthComponent(this);
    }
    
}
