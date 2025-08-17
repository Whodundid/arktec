package com.whodundid.artifactRun.assets.dto;

import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.files.FileHandle;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.whodundid.artifactRun.assets.AbstractGameAssetDTO;
import com.whodundid.artifactRun.assets.AssetLocation;
import com.whodundid.artifactRun.assets.AssetType;

public class BitmapFontAssetDTO extends AbstractGameAssetDTO<BitmapFont> {
    
    //========
    // Fields
    //========
    
    public String filePath;
    public AssetLocation location;
    
    //==============
    // Constructors
    //==============
    
    public BitmapFontAssetDTO(String filePath, AssetLocation location) {
        super(AssetType.FONT_BITMAP);
        
        this.filePath = filePath;
        this.location = location;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public AssetDescriptor<BitmapFont> toDescriptor() {
        FileHandle fnt = fh(location, filePath);
        return new AssetDescriptor<>(fnt, BitmapFont.class);
    }
    
    @Override
    public String assetKey() {
        return fhs(location, filePath);
    }
    
}
