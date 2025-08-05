package com.whodundid.artifactRun.game.data.region;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import com.whodundid.artifactRun.game.data.region.components.EntityEnteredTriggerComponent;
import com.whodundid.artifactRun.game.data.region.components.EntityExitedTriggerComponent;
import com.whodundid.artifactRun.game.data.region.components.EnvironmentSoundsComponent;
import com.whodundid.artifactRun.game.data.region.components.FactionOwnerComponent;
import com.whodundid.artifactRun.game.data.region.components.RegionNameComponent;
import com.whodundid.artifactRun.game.data.region.components.RegionPositionsComponent;
import com.whodundid.artifactRun.game.data.region.components.StatusEffectComponent;
import com.whodundid.artifactRun.game.data.region.util.AbstractRegionComponent;
import com.whodundid.artifactRun.game.data.region.util.RegionComponentType;

public class RegionComponentRegistry {
    
  //===============
    // Static Fields
    //===============
    
    private static final ConcurrentMap<String, Class<? extends AbstractRegionComponent>> TYPE_MAP = new ConcurrentHashMap<>();
    
    //=======================
    // Static Initialization
    //=======================
    
    static {
        registerDefaultComponents();
    }
    
    //================
    // Static Methods
    //================
    
    public static void register(RegionComponentType type, Class<? extends AbstractRegionComponent> clazz) {
        register(type.name(), clazz);
    }
    
    public static void register(String type, Class<? extends AbstractRegionComponent> clazz) {
        TYPE_MAP.put(type, clazz);
    }

    public static Class<? extends AbstractRegionComponent> get(String type) {
        return TYPE_MAP.get(type);
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static void registerDefaultComponents() {
        register(EntityEnteredTriggerComponent.COMPONENT_TYPE, EntityEnteredTriggerComponent.class);
        register(EntityExitedTriggerComponent.COMPONENT_TYPE, EntityExitedTriggerComponent.class);
        register(EnvironmentSoundsComponent.COMPONENT_TYPE, EnvironmentSoundsComponent.class);
        register(FactionOwnerComponent.COMPONENT_TYPE, FactionOwnerComponent.class);
        register(RegionNameComponent.COMPONENT_TYPE, RegionNameComponent.class);
        register(RegionPositionsComponent.COMPONENT_TYPE, RegionPositionsComponent.class);
        register(StatusEffectComponent.COMPONENT_TYPE, StatusEffectComponent.class);
    }
    
    public static void resetRegistry() {
        TYPE_MAP.clear();
        registerDefaultComponents();
    }
    
}
