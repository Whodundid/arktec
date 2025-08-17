package com.whodundid.artifactRun.game.data.assets.types;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.assets.loaders.TextureLoader;
import com.badlogic.gdx.files.FileHandle;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.Texture.TextureFilter;
import com.badlogic.gdx.graphics.Texture.TextureWrap;
import com.whodundid.artifactRun.game.data.assets.AbstractGameAssetDTO;
import com.whodundid.artifactRun.game.data.assets.AssetLocation;
import com.whodundid.artifactRun.game.data.assets.AssetType;
import com.whodundid.artifactRun.json.JsonUtil;

public class TextureAssetDTO extends AbstractGameAssetDTO<Texture> {
    
    //========
    // Fields
    //========
    
    public String filePath;
    public AssetLocation location;
    
    /** Prefer explicit min/mag. */
    public TextureFilter minFilter = TextureFilter.Nearest;
    public TextureFilter magFilter = TextureFilter.Nearest;
    
    /** Prefer explicit U/V wraps. */
    public TextureWrap uWrap = TextureWrap.ClampToEdge;
    public TextureWrap vWrap = TextureWrap.ClampToEdge;
    
    /** Generate mipmaps on load? */
    public boolean useMipMaps = false;
    
    //==============
    // Constructors
    //==============
    
    public TextureAssetDTO(
        String filePath,
        AssetLocation location,
        TextureFilter minFilter,
        TextureFilter magFilter,
        TextureWrap uWrap,
        TextureWrap vWrap,
        boolean useMipMaps
    ){
        super(AssetType.TEXTURE);
        
        this.filePath = filePath;
        this.location = location;
        if (minFilter != null) this.minFilter = minFilter;
        if (magFilter != null) this.magFilter = magFilter;
        if (uWrap != null) this.uWrap = uWrap;
        if (vWrap != null) this.vWrap = vWrap;
        this.useMipMaps = useMipMaps;
    }
    
    //===========
    // Overrides
    //===========
    
    public AssetDescriptor<Texture> toDescriptor() {
        // build the FileHandle based on location
        final FileHandle fh = switch (location) {
            case INTERNAL -> Gdx.files.internal(filePath);
            case LOCAL    -> Gdx.files.local(filePath);
            case EXTERNAL -> Gdx.files.external(filePath);
            case ABSOLUTE -> Gdx.files.absolute(filePath);
        };

        // build loader parameters from JSON fields
        TextureLoader.TextureParameter p = new TextureLoader.TextureParameter();
        p.minFilter  = minFilter;
        p.magFilter  = magFilter;
        p.wrapU      = uWrap;
        p.wrapV      = vWrap;
        p.genMipMaps = useMipMaps;

        // Use the AssetDescriptor ctor that accepts a FileHandle
        return new AssetDescriptor<>(fh, Texture.class, p);
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static TextureAssetDTO fromJson(String jsonString) {
        return JsonUtil.fromJson(jsonString, TextureAssetDTO.class);
    }
    
}
