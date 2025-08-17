package com.whodundid.artifactRun.game.data.tile;

import com.whodundid.artifactRun.game.component.AbstractComponentRegistry;
import com.whodundid.artifactRun.game.data.tile.components.DamageComponent;
import com.whodundid.artifactRun.game.data.tile.components.DecorationComponent;
import com.whodundid.artifactRun.game.data.tile.components.MovementSpeedModifierComponent;
import com.whodundid.artifactRun.game.data.tile.components.TileTypeComponent;
import com.whodundid.artifactRun.game.data.tile.components.VisionModifierComponent;
import com.whodundid.artifactRun.game.data.tile.components.WorldTileRendererComponent;

public class WorldTileComponentRegistry extends AbstractComponentRegistry<AbstractWorldTileComponent> {
    
    //=================
    // Static Instance
    //=================
    
    public static final WorldTileComponentRegistry INSTANCE = new WorldTileComponentRegistry();
    
    //===========
    // Overrides
    //===========
    
    @Override
    public void registerDefaultComponents() {
        register(DamageComponent.COMPONENT_TYPE, DamageComponent.class);
        register(DecorationComponent.COMPONENT_TYPE, DecorationComponent.class);
        register(MovementSpeedModifierComponent.COMPONENT_TYPE, MovementSpeedModifierComponent.class);
        register(TileTypeComponent.COMPONENT_TYPE, TileTypeComponent.class);
        register(VisionModifierComponent.COMPONENT_TYPE, VisionModifierComponent.class);
        register(WorldTileRendererComponent.COMPONENT_TYPE, WorldTileRendererComponent.class);
    }
    
}
