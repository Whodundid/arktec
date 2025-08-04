package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class HealthComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.HEALTH;
    
    //========
    // Fields
    //========
    
    public int maxHealth;
    public int health;
    
    //==============
    // Constructors
    //==============
    
    public HealthComponent() { this (0, 0); }
    public HealthComponent(int maxHealth, int health) {
        super(COMPONENT_TYPE);
        
        this.maxHealth = maxHealth;
        this.health = health;
    }
    
    public HealthComponent(HealthComponent comp) {
        super(COMPONENT_TYPE);
        
        this.maxHealth = comp.maxHealth;
        this.health = comp.health;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public HealthComponent copy() {
        return new HealthComponent(this);
    }
    
}
