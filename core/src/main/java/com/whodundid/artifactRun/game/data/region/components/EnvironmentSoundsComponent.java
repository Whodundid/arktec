package com.whodundid.artifactRun.game.data.region.components;

import com.whodundid.artifactRun.game.data.region.util.AbstractRegionComponent;
import com.whodundid.artifactRun.game.data.region.util.RegionComponentType;

import eutil.datatypes.util.EList;

/**
 * Defines ambient or environmental sounds that play within a region.
 */
public class EnvironmentSoundsComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.ENVIRONMENT_SOUNDS;
    
    //========
    // Fields
    //========
    
    public final EList<SoundEntry> sounds = EList.newList();
    
    //==============
    // Constructors
    //==============
    
    public EnvironmentSoundsComponent(EList<SoundEntry> sounds) {
        super(COMPONENT_TYPE);
        
        this.sounds.addAll(sounds);
    }
    
    public EnvironmentSoundsComponent(EnvironmentSoundsComponent comp) {
        super(COMPONENT_TYPE);
        
        this.sounds.addAll(comp.sounds);
    }
    
    //==================
    // Internal Classes
    //==================
    
    public record SoundEntry(
        String soundId,            // sound file name or asset ID
        float volume,              // 0.0 to 1.0
        boolean loop,              // should it loop
        float minDelaySeconds,     // for random delay between plays
        float maxDelaySeconds,
        SoundCondition condition   // optional logic tag (time of day, etc.)
    ) {}

    public enum SoundCondition {
        ALWAYS,
        DAY_ONLY,
        NIGHT_ONLY
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public EnvironmentSoundsComponent copy() {
        return new EnvironmentSoundsComponent(this);
    }
    
}
