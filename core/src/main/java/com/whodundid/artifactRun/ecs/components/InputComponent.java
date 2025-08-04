package com.whodundid.artifactRun.ecs.components;

import com.whodundid.artifactRun.ecs.IEntityComponent;

public class InputComponent implements IEntityComponent {
    
    //========
    // Fields
    //========
    
    public transient boolean up, down, left, right;
    public transient boolean shoot;

    //==============  
    // Constructors
    //==============
    
    public InputComponent() {}
    public InputComponent(boolean up, boolean down, boolean left, boolean right, boolean shoot) {
        this.up = up;
        this.down = down;
        this.left = left;
        this.right = right;
        this.shoot = shoot;
    }

    public InputComponent(InputComponent other) {
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
    public String getTypeName() {
        return "input";
    }

    @Override
    public IEntityComponent copy() {
        return new InputComponent(this);
    }

}
