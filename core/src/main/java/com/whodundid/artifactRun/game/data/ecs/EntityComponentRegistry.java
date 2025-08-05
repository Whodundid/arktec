package com.whodundid.artifactRun.game.data.ecs;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import com.whodundid.artifactRun.game.data.ecs.components.*;
import com.whodundid.artifactRun.game.data.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.game.data.ecs.util.EntityComponentType;

public class EntityComponentRegistry {
    
    //===============
    // Static Fields
    //===============
    
    private static final ConcurrentMap<String, Class<? extends AbstractEntityComponent>> TYPE_MAP = new ConcurrentHashMap<>();
    
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
        TYPE_MAP.put(type, clazz);
    }

    public static Class<? extends AbstractEntityComponent> get(String type) {
        return TYPE_MAP.get(type);
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static void registerDefaultComponents() {
        register(CollisionComponent.COMPONENT_TYPE, CollisionComponent.class);
        register(HealthComponent.COMPONENT_TYPE, HealthComponent.class);
        register(InputComponent.COMPONENT_TYPE, InputComponent.class);
        register(LifetimeComponent.COMPONENT_TYPE, LifetimeComponent.class);
        register(EntityNameComponent.COMPONENT_TYPE, EntityNameComponent.class);
        register(PositionComponent.COMPONENT_TYPE, PositionComponent.class);
        register(EntityRendererComponent.COMPONENT_TYPE, EntityRendererComponent.class);
        register(SizeComponent.COMPONENT_TYPE, SizeComponent.class);
        register(FactionComponent.COMPONENT_TYPE, FactionComponent.class);
        register(VelocityComponent.COMPONENT_TYPE, VelocityComponent.class);
    }
    
    public static void resetRegistry() {
        TYPE_MAP.clear();
        registerDefaultComponents();
    }
    
}
