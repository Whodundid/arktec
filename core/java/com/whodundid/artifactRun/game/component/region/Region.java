package com.whodundid.artifactRun.game.component.region;

import com.whodundid.artifactRun.game.component.AbstractComponentBasedObject;
import com.whodundid.artifactRun.game.component.ComponentType;
import com.whodundid.artifactRun.io.json.JsonUtil;

public class Region extends AbstractComponentBasedObject<AbstractRegionComponent> {
    
    //==============
    // Constructors
    //==============
    
    public Region() {
        super(ComponentType.REGION);
    }
    
    public Region(Region other) {
        super(ComponentType.REGION, other);
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "Region{id=" + objectId + ", components=" + componentTypeMap.keySet() + "}";
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static Region fromJson(String jsonString) {
        Region entity = JsonUtil.fromJson(jsonString, Region.class);
        entity.rebuildComponentMap();
        return entity;
    }
    
}
