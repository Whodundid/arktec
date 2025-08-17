package com.whodundid.artifactRun.game.component;

import static org.junit.jupiter.api.Assertions.*;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Unit tests for {@link AbstractObjectRegistry}. NOTE: This test uses tiny
 * concrete test doubles for components and objects. You may need to tweak: -
 * the AbstractComponent abstract methods (copy/getComponentType) to match your
 * implementation - the AbstractComponentBasedObject constructor argument
 * (replace super(null) with a real ComponentType if required)
 */
public class AbstractObjectRegistryTest {
    
    private TestRegistry registry;
    private TestObj o1, o2, o3;
    
    @BeforeEach
    void setUp() {
        registry = new TestRegistry();
        o1 = new TestObj();
        o2 = new TestObj();
        o3 = new TestObj();
        
        // seed objects
        registry.addObject(o1);
        registry.addObject(o2);
        registry.addObject(o3);

        // Seed a few components
        registry.addComponent(o1, new CompA());
        registry.addComponent(o1, new CompB());     // o1 has A and B
        registry.addComponent(o2, new CompA());     // o2 has A
        // o3 has none (yet)
    }
    
    @Test
    @DisplayName("view(by single type) returns all objects with that component")
    void viewBySingleType() {
        Set<TestObj> resultA = asSet(registry.view(CompA.class));
        Set<TestObj> resultB = asSet(registry.view(CompB.class));
        
        assertEquals(Set.of(o1, o2), resultA, "CompA should match o1 and o2");
        assertEquals(Set.of(o1), resultB, "CompB should match only o1");
    }
    
    @Test
    @DisplayName("view(by multiple types) returns only objects that have ALL components")
    void viewByMultipleTypes() {
        Set<TestObj> resultAB = asSet(registry.view(CompA.class, CompB.class));
        assertEquals(Set.of(o1), resultAB, "Only o1 has both A and B");
    }
    
    @Test
    @DisplayName("addComponent re-indexes; removeComponent updates the index")
    void addAndRemoveComponent() {
        // Initially, o3 is not in A
        assertFalse(asSet(registry.view(CompA.class)).contains(o3));
        
        // Add A to o3
        registry.addComponent(o3, new CompA());
        assertTrue(asSet(registry.view(CompA.class)).contains(o3));
        
        // Remove A from o3
        registry.removeComponent(o3, CompA.class);
        assertFalse(asSet(registry.view(CompA.class)).contains(o3));
        
        // Removing B from o1 eliminates it from the A∩B view
        assertEquals(Set.of(o1), asSet(registry.view(CompA.class, CompB.class)));
        registry.removeComponent(o1, CompB.class);
        assertTrue(asSet(registry.view(CompA.class, CompB.class)).isEmpty(),
                   "No object should have both after removing B from o1");
    }
    
    @Test
    @DisplayName("removeObject removes from object set and all by-type indexes")
    void removeObject() {
        // Sanity: o1 appears in both A and B indexes
        assertTrue(asSet(registry.view(CompA.class)).contains(o1));
        assertTrue(asSet(registry.view(CompB.class)).contains(o1));
        
        // Remove it
        registry.removeObject(o1);
        
        // Should be gone from all views
        assertFalse(asSet(registry.view(CompA.class)).contains(o1));
        assertFalse(asSet(registry.view(CompB.class)).contains(o1));
    }
    
    @Test
    @DisplayName("Adding the same component class twice doesn't duplicate entries")
    void idempotentAddComponent() {
        // o2 already has A
        int before = asList(registry.view(CompA.class)).size();
        
        // Add another A to o2
        registry.addComponent(o2, new CompA());
        
        int after = asList(registry.view(CompA.class)).size();
        assertEquals(before, after, "Index should not duplicate the same object for the same component type");
    }
    
    @Test
    @DisplayName("addObject indexes all existing components on the object")
    void addObjectIndexesExistingComponents() {
        var t = new TestObj();
        t.addComponent(new CompA());
        t.addComponent(new CompB());
        
        registry.addObject(t);
        
        var ab = asSet(registry.view(CompA.class, CompB.class));
        assertTrue(ab.contains(t), "AB view should include the newly added object");
        assertTrue(ab.size() >= 2);
    }
    
    //------------------------
    // helpers & test doubles
    //------------------------
    
    private static <T> Set<T> asSet(Iterable<T> it) {
        Set<T> s = new HashSet<>();
        for (T x : it) s.add(x);
        return s;
    }
    
    private static <T> List<T> asList(Iterable<T> it) {
        List<T> list = new ArrayList<>();
        for (T x : it) list.add(x);
        return list;
    }
    
    /** Concrete registry for the test components/objects. */
    static final class TestRegistry extends AbstractObjectRegistry<TestComponent, TestObj> {
        TestRegistry() {
            super(TestComponent.class);
        }
    }
    
    /**
     * Minimal object with component support. Replace super(null) with a real
     * ComponentType if your constructor requires it.
     */
    static final class TestObj extends AbstractComponentBasedObject<TestComponent> {
        TestObj() {
            super(null);
        }
    }
    
    /** The component "kinds" for the test components. */
    enum CompKind {
        A, B
    }
    
    /** Common base so we can pass TestComponent.class as the type token. */
    static abstract class TestComponent extends AbstractComponent<CompKind> {
        protected TestComponent(CompKind type) {
            super(type);
        }
    }
    
    /**
     * Concrete test components. Adjust methods to match your
     * AbstractComponent's abstract API if it differs.
     */
    static final class CompA extends TestComponent {
        protected CompA() { super(CompKind.A); }
        @Override public CompA copy() {
            return new CompA();
        }
    }
    
    static final class CompB extends TestComponent {
        protected CompB() { super(CompKind.B); }
        @Override public CompB copy() {
            return new CompB();
        }
    }
    
}
