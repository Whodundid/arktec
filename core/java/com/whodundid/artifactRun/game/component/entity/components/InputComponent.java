package com.whodundid.artifactRun.game.component.entity.components;

import com.whodundid.artifactRun.game.component.entity.AbstractEntityComponent;
import com.whodundid.artifactRun.game.component.entity.EntityComponentType;

public class InputComponent extends AbstractEntityComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final EntityComponentType COMPONENT_TYPE = EntityComponentType.INPUT;
    
    //========
    // Fields
    //========
    
    public transient boolean up, down, left, right;
    public transient boolean shoot;

    //==============  
    // Constructors
    //==============
    
    public InputComponent() { this(false, false, false, false, false); }
    public InputComponent(boolean up, boolean down, boolean left, boolean right, boolean shoot) {
        super(COMPONENT_TYPE);
        
        this.up = up;
        this.down = down;
        this.left = left;
        this.right = right;
        this.shoot = shoot;
    }

    public InputComponent(InputComponent other) {
        super(COMPONENT_TYPE);
        
        this.up = other.up;
        this.down = other.down;
        this.left = other.left;
        this.right = other.right;
        this.shoot = other.shoot;
    }

    //===========  
    // Overrides
    //===========

    @Override
    public InputComponent copy() {
        return new InputComponent(this);
    }

}
