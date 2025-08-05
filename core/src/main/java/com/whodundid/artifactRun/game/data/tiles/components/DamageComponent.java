package com.whodundid.artifactRun.game.data.tiles.components;

import com.whodundid.artifactRun.game.data.tiles.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.data.tiles.util.WorldTileComponentType;

public class DamageComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.DAMAGE;
    
    //========
    // Fields
    //========
    
    public int damageAmount = 1;
    public float damageCooldown = 0.5f;
    
    //==============
    // Constructors
    //==============
    
    public DamageComponent() { this(0, 0.0f); }
    public DamageComponent(int amount, float cooldown) {
        super(COMPONENT_TYPE);
        
        this.damageAmount = amount;
        this.damageCooldown = cooldown;
    }
    
    public DamageComponent(DamageComponent comp) {
        super(COMPONENT_TYPE);
        
        this.damageAmount = comp.damageAmount;
        this.damageCooldown = comp.damageCooldown;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public DamageComponent copy() {
        return new DamageComponent(this);
    }
    
}
