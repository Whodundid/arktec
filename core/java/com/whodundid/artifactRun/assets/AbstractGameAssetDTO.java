package com.whodundid.artifactRun.assets;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.files.FileHandle;
import com.whodundid.artifactRun.io.json.JsonUtil;

public abstract class AbstractGameAssetDTO<T> {
    
    //========
    // Fields
    //========
    
    protected final AssetType type;
    
    //==============
    // Constructors
    //==============
    
    protected AbstractGameAssetDTO(AssetType type) {
        this.type = type;
    }
    
    //===========
    // Abstracts
    //===========
    
    public abstract AssetDescriptor<T> toDescriptor();
    public abstract String assetKey();
    
    //=========
    // Methods
    //=========
    
    public String toJson() {
        return JsonUtil.toPrettyJson(this);
    }
    
    //=========
    // Getters
    //=========
    
    public AssetType getAssetType() {
        return type;
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    protected static FileHandle fh(AssetLocation location, String filePath) {
        return switch (location) {
        case INTERNAL -> Gdx.files.internal(filePath);
        case LOCAL -> Gdx.files.local(filePath);
        case EXTERNAL -> Gdx.files.external(filePath);
        case ABSOLUTE -> Gdx.files.absolute(filePath);
        };
    }
    
    protected static String fhs(AssetLocation location, String filePath) {
        return fh(location, filePath).path();
    }
    
}
