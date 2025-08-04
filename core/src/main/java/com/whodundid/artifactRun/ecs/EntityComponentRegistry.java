package com.whodundid.artifactRun.ecs;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import com.whodundid.artifactRun.ecs.components.*;
import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class EntityComponentRegistry {
    
    //===============
    // Static Fields
    //===============
    
    private static final ConcurrentMap<String, Class<? extends AbstractEntityComponent>> typeMap = new ConcurrentHashMap<>();
    
    //=======================
    // Static Initialization
    //=======================
    
    static {
        registerDefaultComponents();
    }
    
    //================
    // Static Methods
    //================
    
    public static void register(EntityComponentType type, Class<? extends AbstractEntityComponent> clazz) {
        register(type.name(), clazz);
    }
    
    public static void register(String type, Class<? extends AbstractEntityComponent> clazz) {
        typeMap.put(type, clazz);
    }

    public static Class<? extends AbstractEntityComponent> get(String type) {
        return typeMap.get(type);
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static void registerDefaultComponents() {
        register(CollisionComponent.COMPONENT_TYPE, CollisionComponent.class);
        register(HealthComponent.COMPONENT_TYPE, HealthComponent.class);
        register(InputComponent.COMPONENT_TYPE, InputComponent.class);
        register(LifetimeComponent.COMPONENT_TYPE, LifetimeComponent.class);
        register(PositionComponent.COMPONENT_TYPE, PositionComponent.class);
        register(EntityRendererComponent.COMPONENT_TYPE, EntityRendererComponent.class);
        register(SizeComponent.COMPONENT_TYPE, SizeComponent.class);
        register(TeamComponent.COMPONENT_TYPE, TeamComponent.class);
        register(VelocityComponent.COMPONENT_TYPE, VelocityComponent.class);
    }
    
    public static void resetRegistry() {
        typeMap.clear();
        registerDefaultComponents();
    }
    
}
