package com.whodundid.artifactRun.game.data.tiles;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import com.whodundid.artifactRun.game.data.tiles.components.DamageComponent;
import com.whodundid.artifactRun.game.data.tiles.components.DecorationComponent;
import com.whodundid.artifactRun.game.data.tiles.components.MovementSpeedModifierComponent;
import com.whodundid.artifactRun.game.data.tiles.components.TileTypeComponent;
import com.whodundid.artifactRun.game.data.tiles.components.VisionModifierComponent;
import com.whodundid.artifactRun.game.data.tiles.components.WorldTileRendererComponent;
import com.whodundid.artifactRun.game.data.tiles.util.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.data.tiles.util.WorldTileComponentType;

public class WorldTileComponentRegistry {
    
    //===============
    // Static Fields
    //===============
    
    private static final ConcurrentMap<String, Class<? extends AbstractWorldTileComponent>> TYPE_MAP = new ConcurrentHashMap<>();

    //=======================
    // Static Initialization
    //=======================
    
    static {
        registerDefaultComponents();
    }
    
    //================
    // Static Methods
    //================
    
    public static void register(WorldTileComponentType type, Class<? extends AbstractWorldTileComponent> clazz) {
        register(type.name(), clazz);
    }
    
    public static void register(String type, Class<? extends AbstractWorldTileComponent> clazz) {
        TYPE_MAP.put(type, clazz);
    }

    public static Class<? extends AbstractWorldTileComponent> get(String type) {
        return TYPE_MAP.get(type);
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static void registerDefaultComponents() {
        register(DamageComponent.COMPONENT_TYPE, DamageComponent.class);
        register(DecorationComponent.COMPONENT_TYPE, DecorationComponent.class);
        register(MovementSpeedModifierComponent.COMPONENT_TYPE, MovementSpeedModifierComponent.class);
        register(TileTypeComponent.COMPONENT_TYPE, TileTypeComponent.class);
        register(VisionModifierComponent.COMPONENT_TYPE, VisionModifierComponent.class);
        register(WorldTileRendererComponent.COMPONENT_TYPE, WorldTileRendererComponent.class);
    }
    
    public static void resetRegistry() {
        TYPE_MAP.clear();
        registerDefaultComponents();
    }
    
}
