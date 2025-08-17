package com.whodundid.artifactRun;

import com.whodundid.artifactRun.window.ArtifactRunEditorWindow;

public class ArtifactRunEditor {
    
    //========
    // Fields
    //========
    
    private ArtifactRunEditorWindow window;
    
    //======
    // Main
    //======
    
    public static void main(String[] args) {
        new ArtifactRunEditor();
    }
    
    //==============
    // Constructors
    //==============
    
    public ArtifactRunEditor() {
        window = new ArtifactRunEditorWindow();
        
        window.setVisible(true);
    }
    
}
