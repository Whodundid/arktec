package com.whodundid.artifactRun.game.component;

import java.util.Arrays;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public abstract class AbstractObjectRegistry<C extends AbstractComponent<?>, T extends AbstractComponentBasedObject<C>> {
    
    //========
    // Fields
    //========
    
    /** The abstract class for the components. */
    private final Class<? extends C> abstractComponentTypeClass;
    /** The set of objects registered. */
    private final Set<T> objects = new HashSet<>();
    /** A map of component classes to registered objects. [component -> objects that have it] */
    private final Map<Class<? extends C>, Set<T>> byType = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    protected AbstractObjectRegistry(Class<? extends C> abstractComponentTypeClass) {
        this.abstractComponentTypeClass = abstractComponentTypeClass;
    }
    
    //=========
    // Methods
    //=========
    
    public void addObject(T obj) {
        objects.add(obj);
        // seed indices from the object's existing map
        for (Class<? extends C> k : obj.getComponentTypeMap().values()) {
            byType.computeIfAbsent(k, x -> new HashSet<>()).add(obj);
        }
    }
    
    public boolean removeObject(T obj) {
        // if it's not in the set, nothing to do.
        if (!objects.remove(obj)) return false;

        // remove from every component index the object was in
        for (C comp : obj.getComponentList()) {
            Class<? extends C> k = comp.getClass().asSubclass(abstractComponentTypeClass);
            removeFromIndex(k, obj);
        }
        return true;
    }
    
    public void addComponent(T obj, C component) {
        obj.addComponent(component);
        Class<? extends C> k = component.getClass().asSubclass(abstractComponentTypeClass);
        byType.computeIfAbsent(k, x -> new HashSet<>()).add(obj);
    }
    
    public void removeComponent(T obj, Class<? extends C> type) {
        obj.removeComponent(type);

        // now un-index this object for that component class
        Class<? extends C> k = type.asSubclass(abstractComponentTypeClass);
        removeFromIndex(k, obj);
    }
    
    @SafeVarargs
    public final Iterable<T> view(Class<? extends C>... types) {
        // pick smallest seed set, then filter
        var sets = Arrays.stream(types)
            .map(t -> byType.getOrDefault(t, Set.of()))
            .sorted(Comparator.comparingInt(Set::size))
            .toList();
        if (sets.isEmpty() || sets.get(0).isEmpty()) return Collections::emptyIterator;
        var seed = sets.get(0);
        return () -> seed.stream().filter(o -> o.hasAllComponents(types)).iterator();
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    private void removeFromIndex(Class<? extends C> type, T obj) {
        var set = byType.get(type);
        if (set == null) return;
        set.remove(obj);
        if (set.isEmpty()) byType.remove(type);
    }
    
}
