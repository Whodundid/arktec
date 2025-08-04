package com.whodundid.artifactRun.level;

import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

import org.junit.jupiter.api.Test;

class LevelSettingsTest {
    
    @Test
    void testDefaultConstructor() {
        LevelSettings settings = new LevelSettings();
        assertEquals(GameDifficulty.EASY, settings.difficulty);
        assertFalse(settings.cheatMode);
        assertFalse(settings.hardcore);
        assertEquals(180.0f, settings.dayLength);
        assertEquals(120.0f, settings.nightLength);
    }
    
    @Test
    void testCustomConstructor() {
        LevelSettings settings = new LevelSettings(GameDifficulty.INSANE, true, true, 300f, 20f);
        
        assertEquals(GameDifficulty.INSANE, settings.difficulty);
        assertTrue(settings.cheatMode);
        assertTrue(settings.hardcore);
        assertEquals(300.0f, settings.dayLength);
        assertEquals(20.0f, settings.nightLength);
    }
    
    @Test
    void testCopyConstructor() {
        LevelSettings original = new LevelSettings(GameDifficulty.HARD, false, true, 200f, 150f);
        LevelSettings copy = new LevelSettings(original);
        
        assertEquals(original.difficulty, copy.difficulty);
        assertEquals(original.cheatMode, copy.cheatMode);
        assertEquals(original.hardcore, copy.hardcore);
        assertEquals(original.dayLength, copy.dayLength);
        assertEquals(original.nightLength, copy.nightLength);
    }
    
    @Test
    void testSerializationRoundTrip() throws IOException {
        LevelSettings settings = new LevelSettings(GameDifficulty.MEDIUM, true, false, 400f, 100f);
        
        File tempFile = Files.createTempFile("levelsettings", ".json").toFile();
        settings.saveSettingsFile(tempFile);
        
        LevelSettings loaded = LevelSettings.parseLevelSettingsJson(tempFile);
        assertEquals(GameDifficulty.MEDIUM, loaded.difficulty);
        assertTrue(loaded.cheatMode);
        assertFalse(loaded.hardcore);
        assertEquals(400.0f, loaded.dayLength);
        assertEquals(100.0f, loaded.nightLength);
        
        tempFile.delete();
    }
    
    @Test
    void testLoadValuesFromFile() throws IOException {
        // Create dummy settings file
        LevelSettings original = new LevelSettings(GameDifficulty.HARD, true, true, 999f, 666f);
        File tempFile = Files.createTempFile("settingsImport", ".json").toFile();
        original.saveSettingsFile(tempFile);
        
        // Load into existing object
        LevelSettings settings = new LevelSettings(); // uses defaults
        settings.loadValuesFromSettingsFile(tempFile);
        
        assertEquals(GameDifficulty.HARD, settings.difficulty);
        assertTrue(settings.cheatMode);
        assertTrue(settings.hardcore);
        assertEquals(999.0f, settings.dayLength);
        assertEquals(666.0f, settings.nightLength);
        
        tempFile.delete();
    }
    
}
