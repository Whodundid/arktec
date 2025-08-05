package com.whodundid.artifactRun.game.data.region.components;

import com.whodundid.artifactRun.game.data.region.util.AbstractRegionComponent;
import com.whodundid.artifactRun.game.data.region.util.RegionComponentType;

public class RegionNameComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.NAME;
    
    //========
    // Fields
    //========
    
    public String name;
    
    //==============
    // Constructors
    //==============
    
    public RegionNameComponent(String name) {
        super(COMPONENT_TYPE);
        
        this.name = name;
    }
    
    public RegionNameComponent(RegionNameComponent comp) {
        super(COMPONENT_TYPE);
        
        this.name = comp.name;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public RegionNameComponent copy() {
        return new RegionNameComponent(this);
    }
    
}

