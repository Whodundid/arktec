package com.whodundid.artifactRun.window.dialog;

import java.awt.FlowLayout;
import java.awt.GridLayout;
import java.io.File;

import javax.swing.JDialog;
import javax.swing.JFileChooser;
import javax.swing.JOptionPane;

import com.whodundid.artifactRun.window.ArtifactRunEditorWindow;

import eutil.file.EFileUtil;
import eutil.strings.EStringUtil;
import eutil.swing.ESwingUtil;
import eutil.swing.components.EButton;
import eutil.swing.components.EPanel;
import eutil.swing.components.ETextField;

public class ProjectFolderSelectionDialog extends JDialog {
    
    //========
    // Fields
    //========
    
    private ArtifactRunEditorWindow window;
    private ETextField folderNameField;
    private EButton selectFileButton;
    private EButton loadButton;
    
    private static File lastDir;
    private File selectedDir;
    
    //==============
    // Constructors
    //==============
    
    public ProjectFolderSelectionDialog(ArtifactRunEditorWindow window) {
        super(window, "Project Selection", true);
        
        this.window = window;
        
        File dirFile = EFileUtil.userDir();
        String dirString = (lastDir != null) ? lastDir.getPath() : dirFile.getPath();
        if (lastDir == null) lastDir = dirFile;
        folderNameField = new ETextField(dirString, this::openProject);
        folderNameField.setMaxHeight(20);
        
        selectFileButton = new EButton("Select Project Directory", this::openSelectorWindow);
        loadButton = new EButton("Open", this::openProject);
        
        EPanel top = new EPanel(new FlowLayout());
        EPanel bot = new EPanel(new FlowLayout());
        
        top.add(folderNameField);
        top.add(selectFileButton);
        
        bot.add(loadButton);
        
        this.setLayout(new GridLayout(2, 1));
        this.add(top);
        this.add(bot);
    }
    
    //==================
    // Internal Methods
    //==================
    
    protected void openSelectorWindow() {
        JFileChooser chooser = new JFileChooser(lastDir);
        chooser.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);
        int result = chooser.showOpenDialog(window);
        if (result != JFileChooser.APPROVE_OPTION) return;
        File dir = chooser.getSelectedFile();
        if (EFileUtil.notExists(selectedDir)) return;
        selectedDir = dir;
        lastDir = dir;
    }
    
    protected void openProject() {
        String text = folderNameField.getText();
        if (EStringUtil.isNotPopulated(text)) return;
        
        selectedDir = new File(text);
        if (EFileUtil.notExists(selectedDir)) {
            JOptionPane.showMessageDialog(this, "Directory: '" + selectedDir + "' does not exist!");
            return;
        }
        
        lastDir = selectedDir;
        
        this.setVisible(false);
        this.dispose();
    }
    
    //=========
    // Getters
    //=========
    
    public File getSelectedDir() {
        return selectedDir;
    }
    
    //=========
    // Setters
    //=========
    
    public static void setLastDir(File dir) {
        lastDir = dir;
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static File openSelectionDialog(ArtifactRunEditorWindow window) {
        var openerDialog = new ProjectFolderSelectionDialog(window);
        ESwingUtil.centerWithinComponent(openerDialog, window);
        openerDialog.setVisible(true);
        return openerDialog.selectedDir;
    }
    
}
