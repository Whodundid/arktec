package com.whodundid.artifactRun.game.save;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import com.whodundid.artifactRun.game.settings.GameDifficulty;
import com.whodundid.artifactRun.json.JsonUtil;

public class GameSaveSettings {
    
    //========
    // Fields
    //========
    
    public GameDifficulty difficulty;
    public float dayLength;
    public float nightLength;
    
    //==============
    // Constructors
    //==============
    
    public GameSaveSettings() {
        difficulty = GameDifficulty.EASY;
        dayLength = 180.0f;
        nightLength = 120.0f;
    }
    
    public GameSaveSettings(
        GameDifficulty difficulty,
        boolean cheatMode,
        boolean hardcore,
        float dayLength,
        float nightLength
    ){
        this.difficulty = difficulty;
        this.dayLength = dayLength;
        this.nightLength = nightLength;
    }
    
    public GameSaveSettings(GameSaveSettings other) {
        this.difficulty = other.difficulty;
        this.dayLength = other.dayLength;
        this.nightLength = other.nightLength;
    }
    
    //=========
    // Methods
    //=========
    
    public void loadValuesFromSettingsFile(File settingsFile) throws IOException {
        GameSaveSettings parsed = parseLevelSettingsJson(settingsFile);
        
        this.difficulty = parsed.difficulty;
        this.dayLength = parsed.dayLength;
        this.nightLength = parsed.nightLength;
    }
    
    public void saveSettingsFile(File fileToSaveTo) throws IOException {
        String json = toJson();
        Files.write(fileToSaveTo.toPath(), json.getBytes());
    }

    public String toJson() {
        return JsonUtil.toPrettyJson(this);
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static GameSaveSettings parseLevelSettingsJson(File jsonFile) throws IOException {
        Path jsonFilePath = jsonFile.toPath();
        String json = Files.readString(jsonFilePath);
        return parseLevelSettingsJson(json);
    }
    
    public static GameSaveSettings parseLevelSettingsJson(String json) {
        return JsonUtil.fromJson(json, GameSaveSettings.class);
    }
    
}
