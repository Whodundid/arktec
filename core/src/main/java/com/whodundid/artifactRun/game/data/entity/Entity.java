package com.whodundid.artifactRun.game.data.entity;

import com.whodundid.artifactRun.game.data.component.AbstractComponentBasedObject;
import com.whodundid.artifactRun.json.JsonUtil;

public class Entity extends AbstractComponentBasedObject<AbstractEntityComponent> {   
    
    //==============
    // Constructors
    //==============
    
    public Entity() {
        super();
    }
    
    public Entity(Entity other) {
        super(other);
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "Entity{id=" + objectId + ", components=" + componentTypeMap.keySet() + "}";
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static Entity fromJson(String jsonString) {
        Entity entity = JsonUtil.fromJson(jsonString, Entity.class);
        entity.rebuildComponentMap();
        return entity;
    }
    
}
