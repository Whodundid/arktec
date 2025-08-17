package com.whodundid.artifactRun.window.tree;

import javax.swing.tree.DefaultMutableTreeNode;

import com.whodundid.artifactRun.game.component.ComponentType;

public class ProjectResourceCategoryNode extends DefaultMutableTreeNode {
    
    //========
    // Fields
    //========
    
    public ComponentType type;
    
    //==============
    // Constructors
    //==============
    
    public ProjectResourceCategoryNode(ComponentType type) {
        this.type = type;
        this.setUserObject(type.name() + "S");
    }
    
}