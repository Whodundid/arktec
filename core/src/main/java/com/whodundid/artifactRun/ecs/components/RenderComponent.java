package com.whodundid.artifactRun.ecs.components;

import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.whodundid.artifactRun.ecs.IEntityComponent;

public class RenderComponent implements IEntityComponent {
    
    //========
    // Fields
    //========
    
    public TextureRegion sprite;
    
    //==============
    // Constructors
    //==============
    
    public RenderComponent(TextureRegion sprite) {
        this.sprite = sprite;
    }
    
    public RenderComponent(RenderComponent comp) {
        this.sprite = comp.sprite;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String getTypeName() {
        return "render";
    }
    
    @Override
    public IEntityComponent copy() {
        return new RenderComponent(this);
    }
    
}
