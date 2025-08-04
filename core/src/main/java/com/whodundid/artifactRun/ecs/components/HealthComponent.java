package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.EntityComponent;

public class HealthComponent implements EntityComponent {
    
    //========
    // Fields
    //========
    
    public int health;
    public int maxHealth;
    
    //==============
    // Constructors
    //==============
    
    public HealthComponent() {}
    public HealthComponent(int health, int maxHealth) {
        this.health = health;
        this.maxHealth = maxHealth;
    }
    
    public HealthComponent(HealthComponent comp) {
        this.health = comp.health;
        this.maxHealth = comp.maxHealth;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "health";
    }
    
    @Override
    public EntityComponent copy() {
        return new HealthComponent(this);
    }
    
}
