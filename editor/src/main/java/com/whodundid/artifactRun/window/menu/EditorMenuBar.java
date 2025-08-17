package com.whodundid.artifactRun.window.menu;

import javax.swing.JMenu;
import javax.swing.JMenuBar;
import javax.swing.JMenuItem;

import com.whodundid.artifactRun.window.ArtifactRunEditorWindow;

import eutil.swing.listeners.LeftPress;

public class EditorMenuBar extends JMenuBar {
    
    //========
    // Fields
    //========
    
    private ArtifactRunEditorWindow window;
    
    private EditorFileMenuActions fileMenuActions;
    
    private JMenu fileMenu;
    
    //==============
    // Constructors
    //==============
    
    public EditorMenuBar(ArtifactRunEditorWindow window) {
        this.window = window;
        
        createFileMenu();
    }
    
    //================
    // Initialization
    //================
    
    protected void createFileMenu() {
        fileMenu = new JMenu("File");
        
        var newProject = new JMenuItem("New");
        var openProject = new JMenuItem("Open");
        var saveProject = new JMenuItem("Save");
        var saveAsProject = new JMenuItem("Save As");
        var exit = new JMenuItem("Exit");
        
        LeftPress.applyOn(newProject, fileMenuActions::newProject);
        LeftPress.applyOn(openProject, fileMenuActions::openProject);
        LeftPress.applyOn(saveProject, fileMenuActions::saveProject);
        LeftPress.applyOn(saveAsProject, fileMenuActions::saveAsProject);
        LeftPress.applyOn(exit, fileMenuActions::exit);
        
        fileMenu.add(newProject);
        fileMenu.add(openProject);
        fileMenu.add(saveProject);
        fileMenu.add(saveAsProject);
        fileMenu.add(exit);
    }
    
}
