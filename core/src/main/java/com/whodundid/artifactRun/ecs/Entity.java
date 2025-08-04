package com.whodundid.artifactRun.ecs;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import com.whodundid.artifactRun.ecs.util.JsonUtil;

import eutil.datatypes.util.EList;

public class Entity {   
    
    //========
    // Fields
    //========
    
    private final String entityId;
    private final EList<IEntityComponent> componentList = EList.newList();
    private final transient Map<Class<?>, IEntityComponent> componentMap = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    public Entity() {
        this.entityId = UUID.randomUUID().toString();
    }
    
    public Entity(Entity other) {
        this();
        
        var compList = other.componentList;
        for (IEntityComponent c : compList) {
            addComponent(c.copy());
        }
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "Entity{id=" + entityId + ", components=" + componentList.stream().map(c -> c.getClass().getSimpleName()) + "}";
    }
    
    //=========
    // Methods
    //=========
    
    public boolean hasComponent(Class<?> componentClass) {
        return componentMap.containsKey(componentClass);
    }

    public void removeComponent(Class<?> componentClass) {
        componentList.removeIf(c -> c.getClass().equals(componentClass));
        componentMap.remove(componentClass);
    }
    
    public <T extends IEntityComponent> void addComponent(T component) {
        // prevent null components from being added
        if (component == null) return;
        
        Class<?> componentClass = component.getClass();
        
        componentList.removeIf(c -> c.getClass().equals(componentClass));
        componentList.add(component);
        componentMap.put(componentClass, component);
    }
    
    public String toJson() {
        return JsonUtil.toPrettyJson(this);
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    protected void buildComponentMap() {
        componentMap.clear();
        
        for (var c : componentList) {
            componentMap.put(c.getClass(), c);
        }
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static Entity fromJson(String jsonString) {
        Entity entity = JsonUtil.fromJson(jsonString, Entity.class);
        entity.buildComponentMap();
        return entity;
    }
    
    //=========
    // Getters
    //=========
    
    public String getEntityId() {
        return entityId;
    }
    
    public <T extends IEntityComponent> T getComponent(Class<T> componentClass) {
        return componentClass.cast(componentMap.get(componentClass));
    }
    
    public Map<Class<?>, IEntityComponent> getComponentMap() {
        return Collections.unmodifiableMap(componentMap);
    }
    
    public EList<IEntityComponent> getComponentList() {
        return componentList.toUnmodifiableList();
    }
    
}
