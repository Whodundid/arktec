package com.whodundid.artifactRun.level;

import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

import org.junit.jupiter.api.Test;

class LevelInfoTest {
    
    @Test
    void testBasicCreationAndFieldAssignment() {
        LevelInfo info = new LevelInfo("Test Level");
        assertEquals("Test Level", info.levelName);
    }
    
    @Test
    void testLevelVariableCrud() {
        LevelInfo info = new LevelInfo("LevelX");
        info.levelVariables.put("testVar", "123");
        assertEquals("123", info.levelVariables.get("testVar"));
        
        info.levelVariables.remove("testVar");
        assertFalse(info.levelVariables.containsKey("testVar"));
    }
    
    @Test
    void testHashValidity() {
        LevelInfo info = new LevelInfo("LevelX");
        info.startingWorld = "A1";
        info.currentGameStage = "intro";
        info.levelVariables.put("score", "999");
        
        info.levelHash = info.createLevelHash();
        assertTrue(info.isLevelHashValid());
        
        // Break it
        info.levelVariables.put("score", "0");
        assertFalse(info.isLevelHashValid());
    }
    
    @Test
    void testTimestamps() {
        LevelInfo info = new LevelInfo("TimeTest");
        info.creationTimestamp = System.currentTimeMillis();
        info.lastPlayedTimestamp = System.currentTimeMillis();
        assertTrue(info.creationTimestamp > 0);
        assertTrue(info.lastPlayedTimestamp > 0);
    }
    
    @Test
    void testSerializationCycle() throws IOException {
        LevelInfo original = new LevelInfo("SerTest");
        original.startingWorld = "main";
        original.currentGameStage = "stage3";
        original.levelVariables.put("difficulty", "hard");
        
        File temp = Files.createTempFile("levelinfo", ".json").toFile();
        original.saveLevelFile(temp);
        
        LevelInfo readBack = LevelInfo.parseLevelFileJson(temp);
        assertEquals(original.levelName, readBack.levelName);
        assertEquals(original.startingWorld, readBack.startingWorld);
        assertEquals(original.currentGameStage, readBack.currentGameStage);
        assertEquals("hard", readBack.levelVariables.get("difficulty"));
        
        temp.delete();
    }
    
}
