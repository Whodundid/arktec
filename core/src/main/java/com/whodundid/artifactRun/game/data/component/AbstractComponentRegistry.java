package com.whodundid.artifactRun.game.data.component;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

public abstract class AbstractComponentRegistry<T extends AbstractComponent<? extends Enum>> {
    
    //========
    // Fields
    //========
    
    private final ConcurrentMap<String, Class<? extends T>> typeMap = new ConcurrentHashMap<>();
    
    //==============
    // Constructors
    //==============
    
    protected AbstractComponentRegistry() {
        registerDefaultComponents();
    }
    
    //===========
    // Abstracts
    //===========
    
    public abstract void registerDefaultComponents();

    //=========
    // Methods
    //=========
    
    public void register(Enum type, Class<? extends T> clazz) {
        register(type.name(), clazz);
    }
    
    public void register(String type, Class<? extends T> clazz) {
        typeMap.put(type, clazz);
    }
    
    public void resetRegistry() {
        typeMap.clear();
        registerDefaultComponents();
    }
    
    //=========
    // Getters
    //=========
    
    public Class<? extends T> get(String type) {
        return typeMap.get(type);
    }
    
}
