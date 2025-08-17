package com.whodundid.artifactRun.window.tree;

import javax.swing.tree.DefaultMutableTreeNode;

import com.whodundid.artifactRun.game.component.AbstractComponentBasedObject;
import com.whodundid.artifactRun.game.component.ComponentType;

public class ProjectResourceNode extends DefaultMutableTreeNode {
    
    //========
    // Fields
    //========
    
    public String name;
    public final ComponentType type;
    public final AbstractComponentBasedObject<?> object;
    
    //==============
    // Constructors
    //==============
    
    public ProjectResourceNode(String name, ComponentType type, AbstractComponentBasedObject<?> resource) {
        this.name = name;
        this.type = type;
        this.object = resource;
        
        this.setUserObject(name);
    }
    
    //=========
    // Setters
    //=========
    
    public void setTitle(String title) {
        this.name = title;
        this.setUserObject(title);
    }
    
}
