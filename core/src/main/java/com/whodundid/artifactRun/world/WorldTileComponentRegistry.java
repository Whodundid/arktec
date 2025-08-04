package com.whodundid.artifactRun.world;

import java.util.HashMap;
import java.util.Map;

import com.whodundid.artifactRun.world.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.world.util.WorldTileComponentType;

public class WorldTileComponentRegistry {
    
    private static final Map<String, Class<? extends AbstractWorldTileComponent>> typeMap = new HashMap<>();

    static {
        
    }
    
    public static void register(WorldTileComponentType type, Class<? extends AbstractWorldTileComponent> clazz) {
        register(type.name(), clazz);
    }
    
    public static void register(String type, Class<? extends AbstractWorldTileComponent> clazz) {
        typeMap.put(type, clazz);
    }

    public static Class<? extends AbstractWorldTileComponent> get(String type) {
        return typeMap.get(type);
    }
    
}
