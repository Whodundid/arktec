package com.whodundid.artifactRun.game.data.tile;

import com.whodundid.artifactRun.game.data.component.AbstractComponentBasedObject;
import com.whodundid.artifactRun.json.JsonUtil;

public class WorldTile extends AbstractComponentBasedObject<AbstractWorldTileComponent> {
    
    //==============
    // Constructors
    //==============
    
    public WorldTile() {
        super();
    }
    
    public WorldTile(WorldTile other) {
        super(other);
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "WorldTile{id=" + objectId + ", components=" + componentTypeMap.keySet() + "}";
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static WorldTile fromJson(String jsonString) {
        WorldTile entity = JsonUtil.fromJson(jsonString, WorldTile.class);
        entity.rebuildComponentMap();
        return entity;
    }
    
}

