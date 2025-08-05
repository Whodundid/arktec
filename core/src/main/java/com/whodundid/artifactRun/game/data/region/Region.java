package com.whodundid.artifactRun.game.data.region;

import com.whodundid.artifactRun.game.component.AbstractComponentBasedObject;
import com.whodundid.artifactRun.json.JsonUtil;

public class Region extends AbstractComponentBasedObject<AbstractRegionComponent> {
    
    //==============
    // Constructors
    //==============
    
    public Region() {
        super();
    }
    
    public Region(Region other) {
        super(other);
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
