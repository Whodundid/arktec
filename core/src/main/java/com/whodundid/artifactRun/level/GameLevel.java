package com.whodundid.artifactRun.level;

import java.io.IOException;

import com.whodundid.artifactRun.dir.GameLevelDirectory;
import com.whodundid.artifactRun.world.GameWorld;

import eutil.datatypes.util.EList;

public class GameLevel {
    
    //========
    // Fields
    //========
    
    private GameLevelDirectory levelDirectory;
    
    private String levelName;
    
    private LevelSettings settings;
    private LevelPreview preview;
    private LevelData levelData;
    
    private boolean isLoaded;
    private boolean hardcoreSet;
    private boolean cheatModeSet;
    private boolean isLevelValid;
    
    private final EList<GameWorld> levelWorlds = EList.newList();
    
    //==============
    // Constructors
    //==============
    
    public GameLevel(GameLevelDirectory dir) {
        this.levelDirectory = dir;
        
        settings = new LevelSettings();
        preview = new LevelPreview(this);
        levelData = new LevelData(this);
    }
    
    //=========
    // Methods
    //=========
    
    public void loadPreview() {
        // load the preview -- it's alright if it fails
        try {
            preview.load();
        }
        catch (IOException e) {
            System.err.println("Failed to load level preview: " + e);
            e.printStackTrace();
        }
    }
    
    public void load() {
        try {
            isLoaded = false;
            
            // load the settings file
            settings.loadValuesFromSettingsFile(levelDirectory.getLevelSettingsFile());
            // load all game data
            levelData.load();
            
            isLoaded = levelData.isLoaded();
            isLevelValid = levelData.isLevelValid();
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    public boolean saveLevel() {
        try {
            levelData.save();
            settings.saveSettingsFile(levelDirectory.getLevelSettingsFile());
            
            return true;
        }
        catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }
    
    //=========
    // Getters
    //=========
    
    /** @return True if the level's data has been loaded. */
    public boolean isLoaded() { return isLoaded; }
    /** @return True if the level has a valid save hash. */
    public boolean isLevelValid() { return isLevelValid; }
    
    /** @return The directory structure that holds content for this level. */
    public GameLevelDirectory getLevelDirectory() { return levelDirectory; }
    
    // root game level directories
    public LevelSettings getLevelSettings() { return settings; }
    public LevelPreview getLevelPreview() { return preview; }
    public LevelData getLevelData() { return levelData; }
    
    /** The name of the world to load on start. */
    public String getStartingWorld() { return levelData.getStartingWorld(); }
    
    public GameDifficulty getLevelDifficulty() { return settings.difficulty; }
    
    //=========
    // Setters
    //=========
    
    public void setHardcoreMode(boolean val) {
        // once enabled, you can't disable!
        if (hardcoreSet) return;
        
        hardcoreSet = val;
        settings.hardcore = val;
        levelData.writeLevelVariable("game.settings.hardcore", val);
    }
    
    public void setCheatMode(boolean val) {
        // once enabled, you can't disable!
        if (cheatModeSet) return;
        
        cheatModeSet = val;
        settings.cheatMode = val;
        levelData.writeLevelVariable("game.settings.cheatmode", val);
    }
    
    public void setGameDifficulty(GameDifficulty val) { settings.difficulty = val; }
    public void setDayLengthSeconds(float seconds) { settings.dayLength = seconds; }
    public void setNightLengthSeconds(float seconds) { settings.nightLength = seconds; }
    
}
