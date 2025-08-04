package com.whodundid.artifactRun.level;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import com.whodundid.artifactRun.json.JsonUtil;

public class LevelSettings {
    
    //========
    // Fields
    //========
    
    public GameDifficulty difficulty;
    public boolean cheatMode;
    public boolean hardcore;
    public float dayLength;
    public float nightLength;
    
    //==============
    // Constructors
    //==============
    
    public LevelSettings() {
        difficulty = GameDifficulty.EASY;
        cheatMode = false;
        hardcore = false;
        dayLength = 180.0f;
        nightLength = 120.0f;
    }
    
    public LevelSettings(
        GameDifficulty difficulty,
        boolean cheatMode,
        boolean hardcore,
        float dayLength,
        float nightLength
    ){
        this.difficulty = difficulty;
        this.cheatMode = cheatMode;
        this.hardcore = hardcore;
        this.dayLength = dayLength;
        this.nightLength = nightLength;
    }
    
    public LevelSettings(LevelSettings other) {
        this.difficulty = other.difficulty;
        this.hardcore = other.hardcore;
        this.dayLength = other.dayLength;
        this.nightLength = other.nightLength;
    }
    
    //=========
    // Methods
    //=========
    
    public void loadValuesFromSettingsFile(File settingsFile) throws IOException {
        LevelSettings parsed = parseLevelSettingsJson(settingsFile);
        
        this.difficulty = parsed.difficulty;
        this.cheatMode = parsed.cheatMode;
        this.hardcore = parsed.hardcore;
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
    
    public static LevelSettings parseLevelSettingsJson(File jsonFile) throws IOException {
        Path jsonFilePath = jsonFile.toPath();
        String json = Files.readString(jsonFilePath);
        return parseLevelSettingsJson(json);
    }
    
    public static LevelSettings parseLevelSettingsJson(String json) {
        return JsonUtil.fromJson(json, LevelSettings.class);
    }
    
}
