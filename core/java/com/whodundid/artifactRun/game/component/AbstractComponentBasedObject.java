package com.whodundid.artifactRun.game.component;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import com.whodundid.artifactRun.io.json.JsonUtil;

import eutil.datatypes.util.EList;
import eutil.strings.EStringUtil;

public abstract class AbstractComponentBasedObject<T extends AbstractComponent<?>> {
    
    //========
    // Fields
    //========
    
    protected final ComponentType type;
    protected final String objectId;
    
    protected final EList<T> componentList = EList.newList();
    protected final transient Map<String, Class<? extends T>> componentTypeMap = new HashMap<>();
    protected final transient Map<Class<? extends T>, T> componentMap = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    protected AbstractComponentBasedObject(ComponentType type) {
        this.type = type;
        this.objectId = UUID.randomUUID().toString();
    }
    
    protected AbstractComponentBasedObject(ComponentType type, AbstractComponentBasedObject<T> other) {
        this(type);
        
        var compList = other.componentList;
        for (var c : compList) {
            addComponent((T) c.copy());
        }
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "ComponentObject{components=" + componentTypeMap.keySet() + "}";
    }
    
    //=========
    // Methods
    //=========
    
    public boolean hasComponent(Class<? extends T> componentClass) {
        return componentMap.containsKey(componentClass);
    }
    
    public boolean hasComponent(Enum componentType) {
        return componentTypeMap.containsKey(componentType.name());
    }
    
    public boolean hasComponent(String componentTypeName) {
        return componentTypeMap.containsKey(componentTypeName);
    }
    
    public boolean hasAllComponents(Class<? extends T>... types) {
        if (types == null) return true;
        for (var t : types) {
            if (!componentMap.containsKey(t)) return false;
        }
        return true;
    }
    
    public void removeComponent(Class<? extends T> componentClass) {
        componentList.removeIf(c -> c.getClass().equals(componentClass));
        rebuildComponentMap();
    }
    
    public void addComponent(T component) {
        // prevent null components from being added
        if (component == null) return;
        
        Class<?> componentClass = component.getClass();
        
        componentList.removeIf(c -> c.getClass().equals(componentClass));
        componentList.add(component);
        rebuildComponentMap();
    }
    
    public String toJson() {
        return JsonUtil.toPrettyJson(this);
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    protected void rebuildComponentMap() {
        componentMap.clear();
        componentTypeMap.clear();
        
        for (T c : componentList) {
            @SuppressWarnings("unchecked")
            Class<? extends T> k = (Class<? extends T>) c.getClass();
            componentMap.put(k, c);
            componentTypeMap.put(c.getComponentType().name(), k);
        }
    }
    
    //=========
    // Getters
    //=========
    
    public <E extends T> E getComponent(Class<E> componentClass) {
        return componentClass.cast(componentMap.get(componentClass));
    }
    
    public T getComponent(String componentTypeName) {
        // garbage in -- garbage out
        if (EStringUtil.isNotPopulated(componentTypeName)) return null;
        Class<?> componentClass = componentTypeMap.get(componentTypeName);
        // don't care if there isn't a class for it
        if (componentClass == null) return null;
        T comp = componentMap.get(componentClass);
        // if the comp is null, this is weird because we *somehow* have it registered -- so why is it null?!
        if (comp == null) throw new IllegalStateException("We somehow have a reference of a '" + componentTypeName
                                                          + "' but there somehow isn't a component for it!");
        // simple sanity check to make sure that the type names match
        if (!componentTypeName.equals(comp.getComponentType().name())) return null;
        // cast the result and exit
        return (T) componentClass.cast(comp);
    }
    
    public Map<Class<? extends T>, T> getComponentMap() {
        return Collections.unmodifiableMap(componentMap);
    }
    
    public Map<String, Class<? extends T>> getComponentTypeMap() {
        return Collections.unmodifiableMap(componentTypeMap);
    }
    
    public EList<T> getComponentList() {
        return componentList.toUnmodifiableList();
    }
    
    public ComponentType getResourceType() {
        return type;
    }
    
    public String getObjectId() {
        return objectId;
    }
    
}
