package com.whodundid.artifactRun.window.menu;

import java.io.File;

import com.whodundid.artifactRun.window.ArtifactRunEditorWindow;
import com.whodundid.artifactRun.window.dialog.ProjectFolderSelectionDialog;

import eutil.file.EFileUtil;

public class EditorFileMenuActions {
    
    //========
    // Fields
    //========
    
    private final EditorMenuBar menuBar;
    private final ArtifactRunEditorWindow window;
    
    //==============
    // Constructors
    //==============
    
    public EditorFileMenuActions(EditorMenuBar menuBar, ArtifactRunEditorWindow window) {
        this.menuBar = menuBar;
        this.window = window;
    }
    
    //=========
    // Methods
    //=========
    
    public void newProject() {
        
    }
    
    public void openProject() {
        File projectDir = ProjectFolderSelectionDialog.openSelectionDialog(window);
        if (EFileUtil.fileNotExists(projectDir)) return;
        window.getProjectHelper().openProject(projectDir);
    }
    
    public void saveProject() {
        
    }
    
    public void saveAsProject() {
        
    }
    
    public void exit() {
        
    }
    
}
