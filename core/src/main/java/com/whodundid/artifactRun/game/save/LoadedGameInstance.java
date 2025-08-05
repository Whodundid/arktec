package com.whodundid.artifactRun.game.save;

import java.io.IOException;

import com.whodundid.artifactRun.game.GameDifficulty;

public class LoadedGameInstance {
    
    //========
    // Fields
    //========
    
    /** The directory containing all info/settings/data for this level. */
    private GameSaveDirectory saveGameDirectory;
    
    /** Contains data on the save file that loaded the level. */
    private GameSaveInfo saveInfo;
    /** Contains configurable values that the player can modify. */
    private GameSaveSettings settings;
    /** The preview image/data for this save file. */
    private SavePreview preview;
    /** Contains all data relevant to this save file. */
    private GameSaveData data;
    
    /** Flag to indicate whether or not the level's data has been fully loaded. */
    private boolean isLoaded;
    /** Flag to keep track of whether or not hardcore mode was turned on. */
    private boolean isHardcoreSet;
    /** Flag to keep track of whether or not cheatmode was turned on. */
    private boolean isCheatModeSet;
    /** Keeps track of whether or not the game session is elligible for achievements. */
    private boolean isSaveFileValid;
    
    //==============
    // Constructors
    //==============
    
    public LoadedGameInstance(GameSaveDirectory dir) {
        this.saveGameDirectory = dir;
        
        settings = new GameSaveSettings();
        preview = new SavePreview(this);
        data = new GameSaveData(this);
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
            
            // load the info file
            saveInfo = GameSaveInfo.parseLevelFileJson(saveGameDirectory.getLevelInfoFile());
            // load the settings file
            settings.loadValuesFromSettingsFile(saveGameDirectory.getLevelSettingsFile());
            // load all game data
            data.loadData();
            
            // check if the hash is valid before loading variables
            isSaveFileValid = saveInfo.isLevelHashValid();
            
            // set values for hardcore and cheat mode
            isHardcoreSet = saveInfo.isHardcoreModeSet();
            isCheatModeSet = saveInfo.isCheatModeSet();
            
            // lastly, the save file has loaded if the save game data has been loaded
            isLoaded = data.isLoaded();
        }
        catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    public boolean saveLevel() {
        try {
            saveInfo.saveLevelFile(saveGameDirectory.getLevelSettingsFile());
            settings.saveSettingsFile(saveGameDirectory.getLevelSettingsFile());
            
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
    public boolean isLevelValid() { return isSaveFileValid; }
    
    /** @return The directory structure that holds content for this level. */
    public GameSaveDirectory getSaveDirectory() { return saveGameDirectory; }
    /** @return The metadata info for this level. */
    public GameSaveInfo getSaveInfo() { return saveInfo; }
    /** @return The settings file associated with this level. */
    public GameSaveSettings getSaveSettings() { return settings; }
    /** @return The preview for this level. */
    public SavePreview getLevelPreview() { return preview; }
    /** @return The complete set of data: [entities, tiles, scripts, etc.] associated with this level. */
    public GameSaveData getLevelData() { return data; }
    
    /** @return The name of the world to load on start. */
    public String getStartingWorld() { return saveInfo.startingWorld; }
    /** @return The difficulty of this level as designated from the settings file. */
    public GameDifficulty getLevelDifficulty() { return settings.difficulty; }
    
    //=========
    // Setters
    //=========
    
    public void setHardcoreMode(boolean val) {
        // once enabled, you can't disable!
        if (isHardcoreSet) return;
        
        isHardcoreSet = val;
        saveInfo.writeLevelVariable(SettingKeys.HARDCORE_MODE, val);
    }
    
    public void setCheatMode(boolean val) {
        // once enabled, you can't disable!
        if (isCheatModeSet) return;
        
        isCheatModeSet = val;
        saveInfo.writeLevelVariable(SettingKeys.CHEAT_MODE, val);
    }
    
    public void setGameDifficulty(GameDifficulty val) { settings.difficulty = val; }
    public void setDayLengthSeconds(float seconds) { settings.dayLength = seconds; }
    public void setNightLengthSeconds(float seconds) { settings.nightLength = seconds; }
    
}
