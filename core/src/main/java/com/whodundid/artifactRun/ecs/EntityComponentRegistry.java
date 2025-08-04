package com.whodundid.artifactRun.ecs;

import java.util.HashMap;
import java.util.Map;

import com.whodundid.artifactRun.ecs.components.HealthComponent;
import com.whodundid.artifactRun.ecs.components.PositionComponent;

public class EntityComponentRegistry {
    
    private static final Map<String, Class<? extends IEntityComponent>> typeMap = new HashMap<>();

    static {
        register("position", PositionComponent.class);
        register("health", HealthComponent.class);
        // Add more here
    }

    public static void register(String type, Class<? extends IEntityComponent> clazz) {
        typeMap.put(type, clazz);
    }

    public static Class<? extends IEntityComponent> get(String type) {
        return typeMap.get(type);
    }
    
}
