package com.whodundid.artifactRun.save;

import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.settings.GameDifficulty;

class GameSaveSettingsTest {
    
    @Test
    void testDefaultConstructor() {
        GameSaveSettings settings = new GameSaveSettings();
        assertEquals(GameDifficulty.EASY, settings.difficulty);
        assertEquals(180.0f, settings.dayLength);
        assertEquals(120.0f, settings.nightLength);
    }
    
    @Test
    void testCustomConstructor() {
        GameSaveSettings settings = new GameSaveSettings(GameDifficulty.INSANE, true, true, 300f, 20f);
        
        assertEquals(GameDifficulty.INSANE, settings.difficulty);
        assertEquals(300.0f, settings.dayLength);
        assertEquals(20.0f, settings.nightLength);
    }
    
    @Test
    void testCopyConstructor() {
        GameSaveSettings original = new GameSaveSettings(GameDifficulty.HARD, false, true, 200f, 150f);
        GameSaveSettings copy = new GameSaveSettings(original);
        
        assertEquals(original.difficulty, copy.difficulty);
        assertEquals(original.dayLength, copy.dayLength);
        assertEquals(original.nightLength, copy.nightLength);
    }
    
    @Test
    void testSerializationRoundTrip() throws IOException {
        GameSaveSettings settings = new GameSaveSettings(GameDifficulty.MEDIUM, true, false, 400f, 100f);
        
        File tempFile = Files.createTempFile("levelsettings", ".json").toFile();
        settings.saveSettingsFile(tempFile);
        
        GameSaveSettings loaded = GameSaveSettings.parseLevelSettingsJson(tempFile);
        assertEquals(GameDifficulty.MEDIUM, loaded.difficulty);
        assertEquals(400.0f, loaded.dayLength);
        assertEquals(100.0f, loaded.nightLength);
        
        tempFile.delete();
    }
    
    @Test
    void testLoadValuesFromFile() throws IOException {
        // Create dummy settings file
        GameSaveSettings original = new GameSaveSettings(GameDifficulty.HARD, true, true, 999f, 666f);
        File tempFile = Files.createTempFile("settingsImport", ".json").toFile();
        original.saveSettingsFile(tempFile);
        
        // Load into existing object
        GameSaveSettings settings = new GameSaveSettings(); // uses defaults
        settings.loadValuesFromSettingsFile(tempFile);
        
        assertEquals(GameDifficulty.HARD, settings.difficulty);
        assertEquals(999.0f, settings.dayLength);
        assertEquals(666.0f, settings.nightLength);
        
        tempFile.delete();
    }
    
}
