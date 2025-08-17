package com.whodundid.artifactRun.game.component.tile.components;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.whodundid.artifactRun.game.component.tile.AbstractWorldTileComponent;
import com.whodundid.artifactRun.game.component.tile.WorldTileComponentType;

public class WorldTileRendererComponent extends AbstractWorldTileComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final WorldTileComponentType COMPONENT_TYPE = WorldTileComponentType.RENDERER;
    
    public static final String DEFAULT_TILE_STATE = "DEFAULT";
    public static final TileAnimationMode DEFAULT_ANIMATION_MODE = TileAnimationMode.NONE;
    
    //================
    // Static Classes
    //================
    
    public static enum TileAnimationMode {
        NONE,
        SEQUENTIAL,
        RANDOM
    }
    
    //========
    // Fields
    //========
    
    public String defaultSpriteId;
    public String startingState;
    
    public TileAnimationMode animationMode;
    public boolean looping;
    public float frameDuration;
    public float minTimeBetweenStates;
    public float maxTimeBetweenStates;
    
    // These are string keys so they can map to animations at runtime
    public final Map<String, List<String>> animationFrames = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    public WorldTileRendererComponent(String defaultSpriteId) {
        super(COMPONENT_TYPE);
        
        this.defaultSpriteId = defaultSpriteId;
        this.startingState = DEFAULT_TILE_STATE;
        this.animationMode = DEFAULT_ANIMATION_MODE;
    }
    
    public WorldTileRendererComponent(
        String defaultSpriteId,
        String startingState,
        TileAnimationMode animationMode,
        boolean looping,
        float frameDuration,
        float minTimeBetweenStates,
        float maxTimeBetweenStates,
        Map<String, List<String>> animationFrames
    ){
        super(COMPONENT_TYPE);
        
        this.defaultSpriteId = defaultSpriteId;
        this.startingState = startingState;
        this.animationMode = animationMode;
        this.looping = looping;
        this.frameDuration = frameDuration;
        this.minTimeBetweenStates = minTimeBetweenStates;
        this.maxTimeBetweenStates = maxTimeBetweenStates;
        
        if (this.minTimeBetweenStates > this.maxTimeBetweenStates) {
            float temp = minTimeBetweenStates;
            this.minTimeBetweenStates = this.maxTimeBetweenStates;
            this.maxTimeBetweenStates = temp;
        }
        
        for (var e : animationFrames.entrySet()) {
            this.animationFrames.put(e.getKey(), new ArrayList<>(e.getValue()));
        }
    }
    
    public WorldTileRendererComponent(WorldTileRendererComponent comp) {
        super(COMPONENT_TYPE);
        
        this.defaultSpriteId = comp.defaultSpriteId;
        this.startingState = comp.startingState;
        this.animationMode = comp.animationMode;
        this.looping = comp.looping;
        this.frameDuration = comp.frameDuration;
        this.minTimeBetweenStates = comp.minTimeBetweenStates;
        this.maxTimeBetweenStates = comp.maxTimeBetweenStates;
        
        if (this.minTimeBetweenStates > this.maxTimeBetweenStates) {
            float temp = minTimeBetweenStates;
            this.minTimeBetweenStates = this.maxTimeBetweenStates;
            this.maxTimeBetweenStates = temp;
        }
        
        for (var e : comp.animationFrames.entrySet()) {
            animationFrames.put(e.getKey(), new ArrayList<>(e.getValue()));
        }
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public WorldTileRendererComponent copy() {
        return new WorldTileRendererComponent(this);
    }
    
}
