package com.whodundid.artifactRun.world;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import com.whodundid.artifactRun.json.JsonUtil;
import com.whodundid.artifactRun.world.util.AbstractWorldTileComponent;

import eutil.datatypes.util.EList;
import eutil.strings.EStringUtil;

public class WorldTile {
    
    //========
    // Fields
    //========
    
    private final String tileId;
    private final EList<AbstractWorldTileComponent> componentList = EList.newList();
    public final transient Map<String, Class<?>> componentTypeMap = new HashMap<>();
    private final transient Map<Class<?>, AbstractWorldTileComponent> componentMap = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    public WorldTile() {
        this.tileId = UUID.randomUUID().toString();
    }
    
    public WorldTile(WorldTile other) {
        this();
        
        var compList = other.componentList;
        for (AbstractWorldTileComponent c : compList) {
            addComponent(c.copy());
        }
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "WorldTile{id=" + tileId + ", components=" + componentTypeMap.keySet() + "}";
    }
    
    //=========
    // Methods
    //=========
    
    public boolean hasComponent(Class<?> componentClass) {
        return componentMap.containsKey(componentClass);
    }
    
    public boolean hasComponent(String componentTypeName) {
        return componentTypeMap.containsKey(componentTypeName);
    }
    
    public void removeComponent(Class<?> componentClass) {
        componentList.removeIf(c -> c.getClass().equals(componentClass));
        componentMap.remove(componentClass);
    }
    
    public <T extends AbstractWorldTileComponent> void addComponent(T component) {
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
    
    public static WorldTile fromJson(String jsonString) {
        WorldTile tile = JsonUtil.fromJson(jsonString, WorldTile.class);
        tile.buildComponentMap();
        return tile;
    }
    
    //=========
    // Getters
    //=========
    
    public String getTileId() {
        return tileId;
    }
    
    public <T extends AbstractWorldTileComponent> T getComponent(Class<T> componentClass) {
        return componentClass.cast(componentMap.get(componentClass));
    }
    
    public <T extends AbstractWorldTileComponent> T getComponent(String componentTypeName) {
        // garbage in -- garbage out
        if (EStringUtil.isNotPopulated(componentTypeName)) return null;
        Class<?> componentClass = componentTypeMap.get(componentTypeName);
        // don't care if there isn't a class for it
        if (componentClass == null) return null;
        AbstractWorldTileComponent comp = componentMap.get(componentClass);
        // if the comp is null, this is weird because we *somehow* have it registered -- so why is it null?!
        if (comp == null) throw new IllegalStateException("We somehow have a reference of a '" + componentTypeName
                                                          + "' but there somehow isn't a component for it!");
        // simple sanity check to make sure that the type names match
        if (!componentTypeName.equals(comp.getComponentType().name())) return null;
        // cast the result and exit
        return (T) componentClass.cast(comp);
    }
    
    public Map<Class<?>, AbstractWorldTileComponent> getComponentMap() {
        return Collections.unmodifiableMap(componentMap);
    }
    
    public EList<AbstractWorldTileComponent> getComponentList() {
        return componentList.toUnmodifiableList();
    }
    
}

