package com.whodundid.artifactRun.ecs.components;

import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.util.EntityComponentType;

public class EntityRendererComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.RENDERER;
    
    //========
    // Fields
    //========
    
    public TextureRegion sprite;
    
    //==============
    // Constructors
    //==============
    
    public EntityRendererComponent(TextureRegion sprite) {
        super(COMPONENT_TYPE);
        
        this.sprite = sprite;
    }
    
    public EntityRendererComponent(EntityRendererComponent comp) {
        super(COMPONENT_TYPE);
        
        this.sprite = comp.sprite;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public EntityRendererComponent copy() {
        return new EntityRendererComponent(this);
    }
    
}
