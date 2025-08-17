package com.whodundid.artifactRun.window.tree;

import java.awt.Color;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.util.HashMap;
import java.util.Map;

import javax.swing.JTree;
import javax.swing.tree.DefaultMutableTreeNode;
import javax.swing.tree.DefaultTreeCellRenderer;
import javax.swing.tree.DefaultTreeModel;
import javax.swing.tree.TreePath;

import com.whodundid.artifactRun.game.component.ComponentType;
import com.whodundid.artifactRun.window.ArtifactRunEditorWindow;

import eutil.colors.EColorsEnum;
import eutil.swing.listeners.SimpleMouseListener;

public class EditorProjectTree extends JTree implements SimpleMouseListener {
    
    //========
    // Fields
    //========
    
    private ArtifactRunEditorWindow window;
    private DefaultTreeModel treeModel;
    private DefaultMutableTreeNode rootNode;
    private final Map<ComponentType, DefaultMutableTreeNode> resourceNodes = new HashMap<>();
    
    //==============
    // Constructors
    //==============
    
    public EditorProjectTree(ArtifactRunEditorWindow window) {
        this.window = window;
        
        setRootVisible(true);
        setBackground(window.getBackground());
        setCellRenderer(new ProjectResoucesTreeCellRenderer());
        setFont(new Font("Seril", Font.BOLD, 16));
        setRowHeight(20);
        addMouseListener(this);
        
        treeModel = (DefaultTreeModel) getModel();
        rootNode = (DefaultMutableTreeNode) treeModel.getRoot();
        rootNode.removeAllChildren();
        rootNode.setUserObject("No Project");
        treeModel.reload();
    }
    
    //=========
    // Methods
    //=========
    
    public void clearTree() {
        rootNode.removeAllChildren();
        rootNode.setUserObject("No Project");
        treeModel.reload();
        resourceNodes.clear();
    }
    
    public void buildResourcesTree() {
        final var currentGame = window.getActiveProject();
        if (currentGame == null) return;
        
        rootNode.removeAllChildren();
        rootNode.setUserObject(currentGame.getProjectDirectory());
        treeModel.reload();
        
//        var registry = currentGame.getResourceRegistry();
//        var types = registry.getLoadedTypesList();
        
        // build resource type nodes
        for (var type : ComponentType.values()) {
            var typeNode = new ProjectResourceCategoryNode(type);
            resourceNodes.put(type, typeNode);
            rootNode.add(typeNode);
        }
        
//        // populate the nodes with what's in the registry
//        for (var type : types) {
//            var node = resourceNodes.get(type);
//            var assetMap = registry.getResourcesOfType(type);
//            
//            for (var entry : assetMap.entrySet()) {
//                String name = entry.getKey();
//                IEngineResource resource = entry.getValue();
//                 
//                var assetNode = new ProjectResourceNode(name, type, resource);
//                node.add(assetNode);
//            }
//        }
        
        expandPath(new TreePath(rootNode.getPath()));
    }
    
    //=========
    // Getters
    //=========
    
    public ArtifactRunEditorWindow getEditorWindow() {
        return window;
    }
    
    //==================
    // Internal Classes
    //==================
    
    public class ProjectResoucesTreeCellRenderer extends DefaultTreeCellRenderer {
        @Override
        public Component getTreeCellRendererComponent(JTree tree, Object value, boolean sel, boolean expanded, boolean leaf, int row, boolean hasFocus) {
            var component = super.getTreeCellRendererComponent(tree, value, sel, expanded, leaf, row, hasFocus);
            component.setPreferredSize(new Dimension(250, 50));
            setBackground(hasFocus ? EColorsEnum.blue.color : window.getBackground());
            setForeground(hasFocus ? Color.GREEN : Color.WHITE);
            setOpaque(true);
            return component;
        }
    }
    
}
