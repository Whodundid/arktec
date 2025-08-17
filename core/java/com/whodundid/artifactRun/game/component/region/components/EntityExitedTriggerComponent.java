package com.whodundid.artifactRun.game.component.region.components;

import com.whodundid.artifactRun.game.component.region.AbstractRegionComponent;
import com.whodundid.artifactRun.game.component.region.RegionComponentType;

public class EntityExitedTriggerComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.ENTITY_EXITED_TRIGGER;
    
    //========
    // Fields
    //========
    
    public String scriptName;
    
    //==============
    // Constructors
    //==============
    
    public EntityExitedTriggerComponent(String scriptName) {
        super(COMPONENT_TYPE);
        
        this.scriptName = scriptName;
    }
    
    public EntityExitedTriggerComponent(EntityExitedTriggerComponent comp) {
        super(COMPONENT_TYPE);
        
        this.scriptName = comp.scriptName;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public EntityExitedTriggerComponent copy() {
        return new EntityExitedTriggerComponent(this);
    }
    
}

