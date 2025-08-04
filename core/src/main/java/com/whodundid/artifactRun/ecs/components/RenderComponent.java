package com.whodundid.artifactRun.ecs.components;

import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.whodundid.artifactRun.ecs.AbstractEntityComponent;
import com.whodundid.artifactRun.ecs.EntityComponentType;

public class RenderComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.RENDER;
    
    //========
    // Fields
    //========
    
    public TextureRegion sprite;
    
    //==============
    // Constructors
    //==============
    
    public RenderComponent(TextureRegion sprite) {
        super(COMPONENT_TYPE);
        
        this.sprite = sprite;
    }
    
    public RenderComponent(RenderComponent comp) {
        super(COMPONENT_TYPE);
        
        this.sprite = comp.sprite;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public RenderComponent copy() {
        return new RenderComponent(this);
    }
    
}
