package com.whodundid.artifactRun.dir;

import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import javax.imageio.ImageIO;

/**
 * Creates the following directory structure for a game level:
 * 
 * save1/
 * ├── level.json
 * ├── level_preview.png
 * ├── level_settings.json
 * └── data/
 *     ├── entities/
 *     ├── tiles/
 *     ├── worlds/
 *     ├── scripts/
 *     └── textFiles/
 * 
 * @author Hunter
 */
public class GameLevelDirectory {
    
    //========
    // Fields
    //========
    
    /** The directory for this game level. */
    private File gameLevelDirectory;
    
    //----------------
    // root level dir
    //----------------
    
    /** The game level's data file. */
    private File levelDataFile;
    /** A preview image for the save. */
    private File levelPreviewImageFile;
    /** A settings file for this level specifically. */
    private File levelSettingsFile;
    /** Contains all game level's data [worlds, entities, tiles, etc.] */
    private File dataDir;
    
    //----------
    // data dir
    //----------
    
    /** Contains all worlds associated with this level. */
    private File worldsDir;
    /** Where game entities are defined. */
    private File entitiesDir;
    /** Where game world tiles are defined. */
    private File tilesDir;
    /** Contains game scripts. */
    private File scriptsDir;
    /** Contains arbitrary text files that are referenced by scripts. */
    private File textFilesDir;
    
    //==============
    // Constructors
    //==============
    
    public GameLevelDirectory(File levelDir) throws IOException {
        this.gameLevelDirectory = levelDir;
        
        if (levelDir == null) {
            throw new NullPointerException("Error! Level directory is NULL!");
        }
        
        createLevelDirectoryStructure();
    }
    
    //==================
    // Internal Methods
    //==================
    
    protected void createLevelDirectoryStructure() throws IOException {
        createDirectory(gameLevelDirectory);
        
        // root level files
        levelDataFile = new File(gameLevelDirectory, "level.json");
        levelSettingsFile = new File(gameLevelDirectory, "level_settings.json");
        levelPreviewImageFile = new File(gameLevelDirectory, "level_preview.png");
        
        createFile(levelDataFile);
        createFile(levelSettingsFile);
        // we won't create the preview image until there's something to write
        
        // root level directories
        dataDir = new File(gameLevelDirectory, "data");
        
        createDirectory(dataDir);
        
        // data dir directories
        worldsDir = new File(dataDir, "worlds");
        entitiesDir = new File(dataDir, "entities");
        tilesDir = new File(dataDir, "tiles");
        scriptsDir = new File(dataDir, "scripts");
        textFilesDir = new File(dataDir, "textFiles");
        
        createDirectory(worldsDir);
        createDirectory(entitiesDir);
        createDirectory(tilesDir);
        createDirectory(scriptsDir);
        createDirectory(textFilesDir);
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    protected static void createDirectory(File file) throws IOException {
        // if the passed file is null, blow up immediately
        if (file == null) throw new NullPointerException("Cannot create a NULL directory!");
        // if the directory already exists, just move on
        if (file.exists()) return;
        // attempt to create the directory from the Files interface for better error messages
        Path p = file.toPath();
        Files.createDirectories(p);
    }
    
    protected static void createFile(File file) throws IOException {
        // if the passed file is null, blow up immediately
        if (file == null) throw new NullPointerException("Cannot create a NULL directory!");
        // if the file already exists, assume it's good and just move on
        if (file.exists()) return;
        // attempt to create the file from the Files interface for better error messages
        Path p = file.toPath();
        Files.createFile(p);
    }
    
    //=========
    // Methods
    //=========
    
    /**
     * Writes the given buffered image to the level's 'levelPreviewImage' file as a png.
     * 
     * @param image The image to write
     * 
     * @throws NullPointerException Thrown if the given image is null
     * @throws IOException Thrown if anything goes wrong when writing
     */
    public void createPreviewImage(BufferedImage image) throws IOException {
        if (image == null) {
            throw new NullPointerException("Can't create a preview image for level: '" + gameLevelDirectory + "' from NULL input!");
        }
        
        ImageIO.write(image, "png", levelPreviewImageFile);
    }
    
    /**
     * @return True if this level has a preview image
     */
    public boolean hasLevelPreviewImage() {
        return levelPreviewImageFile != null && levelPreviewImageFile.exists();
    }
    
    //=========
    // Getters
    //=========
    
    /** The directory that holds all content for a game level. */
    public File getLevelDir() { return gameLevelDirectory; }
    
    // root level dir stuff
    public File getLevelDataFile() { return levelDataFile; }
    public File getLevelSettingsFile() { return levelSettingsFile; }
    public File getLevelPreviewImageFile() { return levelPreviewImageFile; }
    public File getLevelDataDir() { return dataDir; }
    
    // data dir stuff
    public File getWorldsDir() { return worldsDir; }
    public File getEntitiesDir() { return entitiesDir; }
    public File getTilesDir() { return tilesDir; }
    public File getScriptsDir() { return scriptsDir; }
    public File getTextFilesDir() { return textFilesDir; }
    
}
