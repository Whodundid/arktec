package com.whodundid.artifactRun.project;

import java.io.File;
import java.io.IOException;

import com.whodundid.artifactRun.save.ArtifactRunGameInstance;
import com.whodundid.artifactRun.save.GameSaveDirectory;
import com.whodundid.artifactRun.window.ArtifactRunEditorWindow;

public class EditorProjectHelper {
    
    //========
    // Fields
    //========
    
    private final ArtifactRunEditorWindow window;
    
    //==============
    // Constructors
    //==============
    
    public EditorProjectHelper(ArtifactRunEditorWindow window) {
        this.window = window;
    }
    
    //=========
    // Methods
    //=========
    
    public void newProject(File directory) {
        GameSaveDirectory dir;
        
        try {
            dir = new GameSaveDirectory(directory, true);
        }
        catch (IOException e) {
            e.printStackTrace();
            return;
        }
        
        ArtifactRunGameInstance gameInstance = new ArtifactRunGameInstance(dir);
        ArtifactRunProject project = new ArtifactRunProject(gameInstance);
        
        window.openProject(project);
    }
    
    public void openProject(File projectDir) {
        GameSaveDirectory dir;
        
        try {
            dir = new GameSaveDirectory(projectDir);
        }
        catch (IOException e) {
            e.printStackTrace();
            return;
        }
        
        ArtifactRunGameInstance gameInstance = new ArtifactRunGameInstance(dir);
        ArtifactRunProject project = new ArtifactRunProject(gameInstance);
        
        window.openProject(project);
    }
    
    public void saveProject(ArtifactRunProject project) {
        if (project == null) return;
        project.saveProject();
    }
    
    public void saveAsProject(ArtifactRunProject project, File dirToSaveTo) {
        if (project == null) return;
        project.saveAsProject(dirToSaveTo);
    }
    
}
