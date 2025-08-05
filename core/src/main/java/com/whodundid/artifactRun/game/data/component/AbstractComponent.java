package com.whodundid.artifactRun.game.data.component;

public abstract class AbstractComponent<T extends Enum> {
    
    //========
    // Fields
    //========
    
    protected final T componentType;
    
    //==============
    // Constructors
    //==============
    
    protected AbstractComponent(T type) {
        this.componentType = type;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return super.toString() + ":" + getComponentType().name().toLowerCase();
    }
    
    //===========
    // Abstracts
    //===========
    
    /** @return Creates a copy of this component. */
    public abstract AbstractComponent<T> copy();
    
    //=========
    // Getters
    //=========
    
    /** @return The type of this component used for JSON serialization. */
    public T getComponentType() {
        return componentType;
    }
    
}
