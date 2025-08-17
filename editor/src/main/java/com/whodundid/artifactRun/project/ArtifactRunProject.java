package com.whodundid.artifactRun.project;

import java.io.File;

import com.whodundid.artifactRun.game.save.ArtifactRunGameInstance;

public class ArtifactRunProject {
    
    //========
    // Fields
    //========
    
    private ArtifactRunGameInstance instance;
    
    //==============
    // Constructors
    //==============
    
    public ArtifactRunProject(ArtifactRunGameInstance instance) {
        this.instance = instance;
    }
    
    //=========
    // Methods
    //=========
    
    public void saveProject() {
        instance.saveLevel();
    }
    
    public void saveAsProject(File directoryToSaveTo) {
        
    }
    
    //=========
    // Getters
    //=========
    
    public ArtifactRunGameInstance getGameInstance() {
        return instance;
    }
    
    public File getProjectDirectory() {
        return instance.getSaveDirectory().getLevelDir();
    }
    
}
