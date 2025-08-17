package com.whodundid.artifactRun.assets.dto;

import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.assets.loaders.ShaderProgramLoader;
import com.badlogic.gdx.graphics.glutils.ShaderProgram;
import com.whodundid.artifactRun.assets.AbstractGameAssetDTO;
import com.whodundid.artifactRun.assets.AssetLocation;
import com.whodundid.artifactRun.assets.AssetType;

public class ShaderAssetDTO extends AbstractGameAssetDTO<ShaderProgram> {
    
    //========
    // Fields
    //========
    
    public String shaderName;
    public AssetLocation location;
    public String vertexPath;
    public String fragmentPath;
    public boolean pedantic = false;
    public boolean failIfError = true;
    
    //==============
    // Constructors
    //==============
    
    public ShaderAssetDTO(String shaderName, AssetLocation location, String vertexPath, String fragmentPath) {
        this(shaderName, location, vertexPath, fragmentPath, false, true);
    }
    
    public ShaderAssetDTO(String shaderName, AssetLocation location, String vertexPath, String fragmentPath, boolean pedantic, boolean failIfError) {
        super(AssetType.SOUND);
        
        this.shaderName = shaderName;
        this.location = location;
        this.vertexPath = vertexPath;
        this.fragmentPath = fragmentPath;
        this.pedantic = pedantic;
        this.failIfError = failIfError;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public AssetDescriptor<ShaderProgram> toDescriptor() {
        // ShaderProgram.pedantic is a static flag; set it before load/compile
        ShaderProgram.pedantic = pedantic;
        
        var param = new ShaderProgramLoader.ShaderProgramParameter();
        param.vertexFile = fhs(location, vertexPath);
        param.fragmentFile = fhs(location, fragmentPath);
        
        return new AssetDescriptor<>(shaderName, ShaderProgram.class, param);
    }

    @Override
    public String assetKey() {
        return shaderName;
    }
    
}
