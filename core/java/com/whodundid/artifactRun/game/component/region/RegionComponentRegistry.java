package com.whodundid.artifactRun.game.component.region;

import com.whodundid.artifactRun.game.component.AbstractComponentRegistry;
import com.whodundid.artifactRun.game.component.region.components.EntityEnteredTriggerComponent;
import com.whodundid.artifactRun.game.component.region.components.EntityExitedTriggerComponent;
import com.whodundid.artifactRun.game.component.region.components.EnvironmentSoundsComponent;
import com.whodundid.artifactRun.game.component.region.components.FactionOwnerComponent;
import com.whodundid.artifactRun.game.component.region.components.RegionNameComponent;
import com.whodundid.artifactRun.game.component.region.components.RegionPositionsComponent;
import com.whodundid.artifactRun.game.component.region.components.StatusEffectComponent;

public class RegionComponentRegistry extends AbstractComponentRegistry<AbstractRegionComponent> {
    
    //=================
    // Static Instance
    //=================
    
    public static final RegionComponentRegistry INSTANCE = new RegionComponentRegistry();
    
    //===========
    // Overrides
    //===========
    
    @Override
    public void registerDefaultComponents() {
        register(EntityEnteredTriggerComponent.COMPONENT_TYPE, EntityEnteredTriggerComponent.class);
        register(EntityExitedTriggerComponent.COMPONENT_TYPE, EntityExitedTriggerComponent.class);
        register(EnvironmentSoundsComponent.COMPONENT_TYPE, EnvironmentSoundsComponent.class);
        register(FactionOwnerComponent.COMPONENT_TYPE, FactionOwnerComponent.class);
        register(RegionNameComponent.COMPONENT_TYPE, RegionNameComponent.class);
        register(RegionPositionsComponent.COMPONENT_TYPE, RegionPositionsComponent.class);
        register(StatusEffectComponent.COMPONENT_TYPE, StatusEffectComponent.class);
    }
    
}
