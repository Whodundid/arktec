package com.whodundid.artifactRun.game.component.entity.registry;

import com.whodundid.artifactRun.game.component.AbstractObjectRegistry;
import com.whodundid.artifactRun.game.component.entity.AbstractEntityComponent;
import com.whodundid.artifactRun.game.component.entity.Entity;

public class EntityRegistry extends AbstractObjectRegistry<AbstractEntityComponent, Entity> {
    
    //==============
    // Constructors
    //==============
    
    public EntityRegistry() {
        super(AbstractEntityComponent.class);
    }
    
}
