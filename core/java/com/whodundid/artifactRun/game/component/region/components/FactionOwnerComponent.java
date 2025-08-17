package com.whodundid.artifactRun.game.component.region.components;

import com.whodundid.artifactRun.game.component.region.AbstractRegionComponent;
import com.whodundid.artifactRun.game.component.region.RegionComponentType;

public class FactionOwnerComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.FACTION_OWNER;
    
    //========
    // Fields
    //========
    
    public String factionName;
    
    //==============
    // Constructors
    //==============
    
    public FactionOwnerComponent(String factionName) {
        super(COMPONENT_TYPE);
        
        this.factionName = factionName;
    }
    
    public FactionOwnerComponent(FactionOwnerComponent comp) {
        super(COMPONENT_TYPE);
        
        this.factionName = comp.factionName;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public FactionOwnerComponent copy() {
        return new FactionOwnerComponent(this);
    }
    
}

