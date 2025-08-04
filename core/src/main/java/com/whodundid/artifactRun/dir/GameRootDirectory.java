package com.whodundid.artifactRun.dir;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Creates the following directory structure:
 * 
 * <rootDir>/
 * ├── assets/
 * │   ├── fonts/
 * │   ├── music/
 * │   ├── shaders/
 * │   ├── sounds/
 * │   └── textures/
 * ├── config/
 * ├── logs/
 * └── saves/
 * 
 * @author Hunter Bragg
 */
public class GameRootDirectory {
    
    //========
    // Fields
    //========
    
    /** The root game directory. */
    private File rootDir;
    
    //---------------
    // root game dir
    //---------------
    
    /** Directory containing all game data. */
    private File assetsDir;
    /** Holds game save info. */
    private File savesDir;
    /** Holds the game's various config files. */
    private File configDir;
    /** Contians output logs. */
    private File logsDir;
    
    //------------
    // assets dir
    //------------
    
    /** Contains raw texture data to be used by game objects [png, jpg, etc.] */
    private File texturesDir;
    /** Contains game sound effect data. */
    private File soundsDir;
    /** Contains game music. */
    private File musicDir;
    /** Contains font data either in the form of texture atlases or true-type font files. */
    private File fontsDir;
    /** Contains shaders for graphics stuff. */
    private File shadersDir;
    
    //==============
    // Constructors
    //==============
    
    public GameRootDirectory(File rootDir) throws IOException {
        this.rootDir = rootDir;
        
        if (rootDir == null) {
            throw new NullPointerException("Error! Game directory is NULL!");
        }
        
        createGameDirectoryStructure();
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public String toString() {
        return "GameRootDirectory@" + rootDir.getAbsolutePath();
    }
    
    //==================
    // Internal Methods
    //==================
    
    protected void createGameDirectoryStructure() throws IOException {
        createDirectory(rootDir);
        
        // root game directories
        assetsDir = new File(rootDir, "assets");
        savesDir = new File(rootDir, "saves");
        configDir = new File(rootDir, "config");
        logsDir = new File(rootDir, "logs");
        
        createDirectory(assetsDir);
        createDirectory(savesDir);
        createDirectory(configDir);
        createDirectory(logsDir);
        
        // assets dir directories
        texturesDir = new File(assetsDir, "textures");
        soundsDir = new File(assetsDir, "sounds");
        musicDir = new File(assetsDir, "music");
        fontsDir = new File(assetsDir, "fonts");
        shadersDir = new File(assetsDir, "shaders");
        
        createDirectory(texturesDir);
        createDirectory(soundsDir);
        createDirectory(musicDir);
        createDirectory(fontsDir);
        createDirectory(shadersDir);
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
    
    //=========
    // Getters
    //=========
    
    /** The directory that holds all content for the game. */
    public File getRootGameDir() { return rootDir; }
    
    // root game dir stuff
    public File getAssetsDir() { return assetsDir; }
    public File getSavesDir() { return savesDir; }
    public File getConfigDir() { return configDir; }
    public File getLogsDir() { return logsDir; }
    
    // assets dir stuff
    public File getTexturesDir() { return texturesDir; }
    public File getSoundsDir() { return soundsDir; }
    public File getMusicDir() { return musicDir; }
    public File getFontsDir() { return fontsDir; }
    public File getShadersDir() { return shadersDir; }
    
}
