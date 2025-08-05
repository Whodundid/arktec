package com.whodundid.artifactRun.game.save;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;

public class SavePreview {
    
    //========
    // Fields
    //========
    
    /** The level for which this preview is for. */
    private final LoadedGameInstance level;
    
    /** Contains the image data for the level's preview. */
    private BufferedImage previewImage;
    
    //==============
    // Constructors
    //==============
    
    public SavePreview(LoadedGameInstance level) {
        this.level = level;
    }
    
    //=========
    // Methods
    //=========
    
    public void load() throws IOException {
        // reset this back to null
        previewImage = null;
        
        // grab the level's directory to pull the preview image from
        var dir = level.getSaveDirectory();
        
        // don't care if there isn't a preview image file
        if (!dir.hasLevelPreviewImage()) return;
        
        // attempt to read the preview image as a buffered image
        File previewImageFile = dir.getLevelPreviewImageFile();
        previewImage = ImageIO.read(previewImageFile);
    }
    
    /**
     * @return True if the level preview image was successfully loaded
     */
    public boolean isPreviewLoaded() {
        return previewImage != null;
    }
    
    //=========
    // Getters
    //=========
    
    public BufferedImage getPreviewImage() {
        return previewImage;
    }
    
}
