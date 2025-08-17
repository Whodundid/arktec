package com.whodundid.artifactRun.window.tree;

import javax.swing.JMenuItem;
import javax.swing.JPopupMenu;
import javax.swing.tree.DefaultMutableTreeNode;

import com.whodundid.artifactRun.game.component.ComponentType;

import eutil.strings.EStringUtil;
import eutil.swing.listeners.LeftPress;

public class ProjectTreeRCM extends JPopupMenu {
    
    //========
    // Fields
    //========
    
    public final EditorProjectTree tree;
    public final DefaultMutableTreeNode node;
    private JMenuItem newResource;
    private JMenuItem copy;
    private JMenuItem paste;
    private JMenuItem delete;
    private ComponentType type;
    
    //==============
    // Constructors
    //==============
    
    public ProjectTreeRCM(EditorProjectTree tree, DefaultMutableTreeNode node) {
        this.tree = tree;
        this.node = node;
        
        copy = new JMenuItem("Copy");
        paste = new JMenuItem("Paste");
        delete = new JMenuItem("Delete");
        
        
        if (node instanceof ProjectResourceCategoryNode n) {
            var type = n.type;
            String typeName = String.valueOf(type).toLowerCase();
            typeName = EStringUtil.capitalFirst(typeName);
            newResource = new JMenuItem("New " + typeName);
            add(newResource);
            this.type = type;
        }
        else if (node instanceof ProjectResourceNode n) {
            var type = n.type;
            String typeName = String.valueOf(type).toLowerCase();
            typeName = EStringUtil.capitalFirst(typeName);
            newResource = new JMenuItem("New " + typeName);
            add(newResource);
            add(copy);
            add(paste);
            add(delete);
            this.type = type;
        }
        
        if (newResource != null) {
            LeftPress.applyOn(newResource, () -> {
                if (type != null) {
                    tree.getEditorWindow().openResourceCreatorPanel(type);
                }
            });
        }
    }
    
}
