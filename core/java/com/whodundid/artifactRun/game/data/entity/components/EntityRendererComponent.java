package com.whodundid.artifactRun.game.data.entity.components;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.whodundid.artifactRun.game.data.entity.AbstractEntityComponent;
import com.whodundid.artifactRun.game.data.entity.EntityComponentType;

public class EntityRendererComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.RENDERER;
    
    //================
    // Static Classes
    //================
    
    public static enum EntityAnimationState {
        IDLE_UP,
        IDLE_DOWN,
        IDLE_LEFT,
        IDLE_RIGHT,
        
        WALK_UP,
        WALK_DOWN,
        WALK_LEFT,
        WALK_RIGHT,
        
        ATTACK_UP,
        ATTACK_DOWN,
        ATTACK_LEFT,
        ATTACK_RIGHT
    }
    
    //========
    // Fields
    //========
    
    public String defaultSpriteId;
    public EntityAnimationState startingState;
    
    public boolean isAnimated;
    public float frameDuration;
    public boolean looping;
    
    // These are string keys so they can map to animations at runtime
    public final Map<EntityAnimationState, List<String>> animationFrames = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    public EntityRendererComponent(String defaultSpriteId) {
        super(COMPONENT_TYPE);
        
        this.defaultSpriteId = defaultSpriteId;
        this.startingState = EntityAnimationState.IDLE_DOWN;
        this.isAnimated = false;
        this.frameDuration = 0.0f;
        this.looping = false;
    }
    
    public EntityRendererComponent(
        String defaultSpriteId,
        EntityAnimationState startingState,
        boolean isAnimated,
        float frameDuration,
        boolean looping,
        Map<EntityAnimationState, List<String>> animationFrames
    ){
        super(COMPONENT_TYPE);
        
        this.defaultSpriteId = defaultSpriteId;
        this.startingState = startingState;
        this.isAnimated = isAnimated;
        this.frameDuration = frameDuration;
        this.looping = looping;
        
        for (var e : animationFrames.entrySet()) {
            this.animationFrames.put(e.getKey(), new ArrayList<>(e.getValue()));
        }
    }
    
    public EntityRendererComponent(EntityRendererComponent comp) {
        super(COMPONENT_TYPE);
        
        this.defaultSpriteId = comp.defaultSpriteId;
        this.startingState = comp.startingState;
        this.isAnimated = comp.isAnimated;
        this.frameDuration = comp.frameDuration;
        this.looping = comp.looping;
        
        for (var e : comp.animationFrames.entrySet()) {
            animationFrames.put(e.getKey(), new ArrayList<>(e.getValue()));
        }
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public EntityRendererComponent copy() {
        return new EntityRendererComponent(this);
    }
    
}
