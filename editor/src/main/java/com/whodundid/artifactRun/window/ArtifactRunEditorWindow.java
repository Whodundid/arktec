package com.whodundid.artifactRun.window;

import java.awt.Color;

import javax.swing.JFrame;

import com.whodundid.artifactRun.game.component.ComponentType;
import com.whodundid.artifactRun.project.ArtifactRunProject;
import com.whodundid.artifactRun.project.EditorProjectHelper;
import com.whodundid.artifactRun.window.menu.EditorMenuBar;
import com.whodundid.artifactRun.window.tree.ProjectResourceNode;

public class ArtifactRunEditorWindow extends JFrame {
    
    //========
    // Fields
    //========
    
    private EditorProjectHelper projectHelper;
    private EditorMenuBar menuBar;
    
    private ArtifactRunProject activeProject;
    
    //==============
    // Constructors
    //==============
    
    public ArtifactRunEditorWindow() {
        super("Artifact Run Editor");
        
        projectHelper = new EditorProjectHelper(this);
        menuBar = new EditorMenuBar(this);
        
        this.setBackground(Color.DARK_GRAY);
        this.setSize(640, 480);
        
        this.setJMenuBar(menuBar);
    }
    
    //===========
    // Overrides
    //===========
    
    //=========
    // Methods
    //=========
    
    public void openProject(ArtifactRunProject project) {
        if (project == null) return;
        
        activeProject = project;
    }
    
    public void openResourceCreatorPanel(ComponentType type) { openResourceCreatorPanel(type, null); }
    public void openResourceCreatorPanel(ComponentType type, ProjectResourceNode node) {
        if (type == null) return;
    }
    
    //=========
    // Getters
    //=========
    
    public EditorProjectHelper getProjectHelper() {
        return projectHelper;
    }
    
    public ArtifactRunProject getActiveProject() {
        return activeProject;
    }
    
}
