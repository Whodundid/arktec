package com.whodundid.artifactRun.ecs;

import java.util.HashMap;
import java.util.Map;

import com.whodundid.artifactRun.ecs.components.CollisionComponent;
import com.whodundid.artifactRun.ecs.components.HealthComponent;
import com.whodundid.artifactRun.ecs.components.InputComponent;
import com.whodundid.artifactRun.ecs.components.LifetimeComponent;
import com.whodundid.artifactRun.ecs.components.PositionComponent;
import com.whodundid.artifactRun.ecs.components.EntityRendererComponent;
import com.whodundid.artifactRun.ecs.components.SizeComponent;
import com.whodundid.artifactRun.ecs.components.TeamComponent;
import com.whodundid.artifactRun.ecs.components.VelocityComponent;
import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class EntityComponentRegistry {
    
    private static final Map<String, Class<? extends AbstractEntityComponent>> typeMap = new HashMap<>();

    static {
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
    
    public static void register(EntityComponentType type, Class<? extends AbstractEntityComponent> clazz) {
        register(type.name(), clazz);
    }
    
    public static void register(String type, Class<? extends AbstractEntityComponent> clazz) {
        typeMap.put(type, clazz);
    }

    public static Class<? extends AbstractEntityComponent> get(String type) {
        return typeMap.get(type);
    }
    
}
