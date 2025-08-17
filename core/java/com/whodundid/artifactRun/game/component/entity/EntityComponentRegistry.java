package com.whodundid.artifactRun.game.component.entity;

import com.whodundid.artifactRun.game.component.AbstractComponentRegistry;
import com.whodundid.artifactRun.game.component.entity.components.CollisionComponent;
import com.whodundid.artifactRun.game.component.entity.components.EntityNameComponent;
import com.whodundid.artifactRun.game.component.entity.components.EntityRendererComponent;
import com.whodundid.artifactRun.game.component.entity.components.FactionComponent;
import com.whodundid.artifactRun.game.component.entity.components.HealthComponent;
import com.whodundid.artifactRun.game.component.entity.components.InputComponent;
import com.whodundid.artifactRun.game.component.entity.components.LifetimeComponent;
import com.whodundid.artifactRun.game.component.entity.components.PositionComponent;
import com.whodundid.artifactRun.game.component.entity.components.SizeComponent;
import com.whodundid.artifactRun.game.component.entity.components.VelocityComponent;

public class EntityComponentRegistry extends AbstractComponentRegistry<AbstractEntityComponent> {
    
    //=================
    // Static Instance
    //=================
    
    public static final EntityComponentRegistry INSTANCE = new EntityComponentRegistry();
    
    //===========
    // Overrides
    //===========
    
    @Override
    public void registerDefaultComponents() {
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
    
}
