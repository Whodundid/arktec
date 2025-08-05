package com.whodundid.artifactRun.game.data.region.components;

import com.whodundid.artifactRun.game.data.region.util.AbstractRegionComponent;
import com.whodundid.artifactRun.game.data.region.util.RegionComponentType;

public class EntityEnteredTriggerComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.ENTITY_ENTERED_TRIGGER;
    
    //========
    // Fields
    //========
    
    public String scriptName;
    
    //==============
    // Constructors
    //==============
    
    public EntityEnteredTriggerComponent(String scriptName) {
        super(COMPONENT_TYPE);
        
        this.scriptName = scriptName;
    }
    
    public EntityEnteredTriggerComponent(EntityEnteredTriggerComponent comp) {
        super(COMPONENT_TYPE);
        
        this.scriptName = comp.scriptName;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public EntityEnteredTriggerComponent copy() {
        return new EntityEnteredTriggerComponent(this);
    }
    
}

