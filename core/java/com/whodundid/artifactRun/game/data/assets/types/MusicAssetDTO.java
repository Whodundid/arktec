package com.whodundid.artifactRun.game.data.assets.types;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.audio.Music;
import com.badlogic.gdx.files.FileHandle;
import com.whodundid.artifactRun.game.data.assets.AbstractGameAssetDTO;
import com.whodundid.artifactRun.game.data.assets.AssetLocation;
import com.whodundid.artifactRun.game.data.assets.AssetType;

public class MusicAssetDTO extends AbstractGameAssetDTO<Music> {
    
    //========
    // Fields
    //========
    
    public String filePath;
    public AssetLocation location;
    
    //==============
    // Constructors
    //==============
    
    public MusicAssetDTO(String filePath, AssetLocation location) {
        super(AssetType.SOUND);
        
        this.filePath = filePath;
        this.location = location;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public AssetDescriptor<Music> toDescriptor() {
        FileHandle fh = switch (location) {
            case INTERNAL -> Gdx.files.internal(filePath);
            case LOCAL    -> Gdx.files.local(filePath);
            case EXTERNAL -> Gdx.files.external(filePath);
            case ABSOLUTE -> Gdx.files.absolute(filePath);
        };
        return new AssetDescriptor<>(fh, Music.class);
    }

    @Override
    public String assetKey() {
        return switch (location) {
            case INTERNAL -> Gdx.files.internal(filePath).path();
            case LOCAL    -> Gdx.files.local(filePath).path();
            case EXTERNAL -> Gdx.files.external(filePath).path();
            case ABSOLUTE -> Gdx.files.absolute(filePath).path();
        };
    }
    
}
