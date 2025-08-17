package com.whodundid.artifactRun.assets;

import java.util.Collections;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.assets.AssetManager;

/**
 * Manages a family of assets (all of type A) using a shared AssetManager.
 *
 * @param <A> Concrete LibGDX asset type (e.g., Texture, Sound, Music)
 * @param <T> DTO that can produce an AssetDescriptor<A> and its asset key
 * 
 * @author Hunter
 */
public abstract class AbstractAssetRegistry<A, T extends AbstractGameAssetDTO<A>> {
    
    //========
    // Fields
    //========
    
    /** The class type for this registry. */
    private final Class<A> assetClass;
    /** Injected, shared game-wide. */
    private final AssetManager manager;
    
    /** Registered-but-not-yet-queued descriptors by key. */
    private final ConcurrentMap<String, AssetDescriptor<A>> registered = new ConcurrentHashMap<>();
    
    //==============
    // Constructors
    //==============
    
    protected AbstractAssetRegistry(Class<A> assetClass, AssetManager manager) {
        this.assetClass = assetClass;
        this.manager = manager;
    }
    
    //=========
    // Methods
    //=========
    
    /** Removes all registrations and unloads them from the manager. */
    public void resetRegistry() {
        for (String key : registered.keySet()) {
            if (manager.isLoaded(key)) {
                manager.unload(key);
            }
        }
        registered.clear();
    }
    
    /** Registers a DTO; does not queue load yet. Throws on duplicate keys. */
    public void register(T asset) {
        if (asset == null) return;

        AssetDescriptor<A> descriptor = asset.toDescriptor();
        if (descriptor == null) {
            throw new IllegalStateException("Asset provides no descriptor: " + asset);
        }

        final String key = asset.assetKey();
        if (key == null || key.isEmpty()) {
            throw new IllegalStateException("Asset key is null/empty for: " + asset);
        }

        if (registered.putIfAbsent(key, descriptor) != null) {
            throw new IllegalStateException("Duplicate asset key registered: '" + key + "'");
        }
    }
    
    /** Asynchronous pattern: call each frame to pump loading. Returns true when done. */
    public boolean tickAsyncLoading() {
        // returns true when all queued loads are complete
        return manager.update();
    }
    
    public void loadAssetsBlocking() {
        beginLoad();
        manager.finishLoading();
    }
    
    public void loadAssetsAsync() {
        beginLoad();
    }
    
    public void unloadSingleAsset(String assetName) {
        if (!registered.containsKey(assetName)) {
            throw new IllegalArgumentException("The registry does not contain an entry for: '" + assetName + "'!");
        }
        
        manager.unload(assetName);
        registered.remove(assetName);
    }
    
    public void unloadAssets() {
        for (String key : registered.keySet()) {
            if (manager.isLoaded(key)) {
                manager.unload(key);
            }
        }
        registered.clear();
    }
    
    //==================
    // Internal Methods
    //==================
    
    protected void beginLoad() {
        for (var d : registered.values()) {
            manager.load(d);
        }
    }
    
    //=========
    // Getters
    //=========
    
    public Class<A> getAssetClass() {
        return assetClass;
    }
    
    public boolean isLoaded() {
        return manager.isFinished();
    }
    
    public float getLoadingPercentage() {
        return manager.getProgress();
    }
    
    public A getAsset(String fileName) {
        return manager.get(fileName, assetClass);
    }
    
    /** @return The assets by name managed in this registry. */
    public Set<String> getRegisteredAssets() {
        return Collections.unmodifiableSet(registered.keySet());
    }
    
}
