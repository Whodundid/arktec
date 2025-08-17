package com.whodundid.artifactRun.game.data.assets;

import com.badlogic.gdx.assets.AssetDescriptor;
import com.whodundid.artifactRun.json.JsonUtil;

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
    
}
