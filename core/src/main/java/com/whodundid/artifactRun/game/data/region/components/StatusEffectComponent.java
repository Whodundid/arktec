package com.whodundid.artifactRun.game.data.region.components;

import com.whodundid.artifactRun.game.data.region.util.AbstractRegionComponent;
import com.whodundid.artifactRun.game.data.region.util.RegionComponentType;

public class StatusEffectComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.STATUS_EFFECT;
    
    //========
    // Fields
    //========
    
    /** If true, applies the effect; if false, removes the effect. */
    public boolean apply;
    /** The name of an effect to apply. */
    public String effectName;
    /** The name of a script to run to determine if the status effect should trigger. */
    public String conditionScriptName;
    
    //==============
    // Constructors
    //==============
    
    public StatusEffectComponent(boolean apply, String effectName) {
        this(apply, effectName, null);
    }
    
    public StatusEffectComponent(boolean apply, String effectName, String conditionScriptName) {
        super(COMPONENT_TYPE);
        
        this.apply = apply;
        this.effectName = effectName;
        this.conditionScriptName = conditionScriptName;
    }
    
    public StatusEffectComponent(StatusEffectComponent comp) {
        super(COMPONENT_TYPE);
        
        this.apply = comp.apply;
        this.effectName = comp.effectName;
        this.conditionScriptName = comp.conditionScriptName;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public StatusEffectComponent copy() {
        return new StatusEffectComponent(this);
    }
    
}

