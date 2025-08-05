package com.whodundid.artifactRun.game.save;

import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;

import org.junit.jupiter.api.Test;

class GameSaveInfoTest {
    
    @Test
    void testBasicCreationAndFieldAssignment() {
        GameSaveInfo info = new GameSaveInfo("Test Level");
        assertEquals("Test Level", info.saveName);
    }
    
    @Test
    void testLevelVariableCrud() {
        GameSaveInfo info = new GameSaveInfo("LevelX");
        info.gameVariables.put("testVar", "123");
        assertEquals("123", info.gameVariables.get("testVar"));
        
        info.gameVariables.remove("testVar");
        assertFalse(info.gameVariables.containsKey("testVar"));
    }
    
    @Test
    void testHashValidity() {
        GameSaveInfo info = new GameSaveInfo("LevelX");
        info.startingWorld = "A1";
        info.currentGameStage = "intro";
        info.gameVariables.put("score", "999");
        
        info.saveHash = info.createLevelHash();
        assertTrue(info.isLevelHashValid());
        
        // Break it
        info.gameVariables.put("score", "0");
        assertFalse(info.isLevelHashValid());
    }
    
    @Test
    void testTimestamps() {
        GameSaveInfo info = new GameSaveInfo("TimeTest");
        info.creationTimestamp = System.currentTimeMillis();
        info.lastPlayedTimestamp = System.currentTimeMillis();
        assertTrue(info.creationTimestamp > 0);
        assertTrue(info.lastPlayedTimestamp > 0);
    }
    
    @Test
    void testSerializationCycle() throws IOException {
        GameSaveInfo original = new GameSaveInfo("SerTest");
        original.startingWorld = "main";
        original.currentGameStage = "stage3";
        original.gameVariables.put("difficulty", "hard");
        
        File temp = Files.createTempFile("levelinfo", ".json").toFile();
        original.saveLevelFile(temp);
        
        GameSaveInfo readBack = GameSaveInfo.parseLevelFileJson(temp);
        assertEquals(original.saveName, readBack.saveName);
        assertEquals(original.startingWorld, readBack.startingWorld);
        assertEquals(original.currentGameStage, readBack.currentGameStage);
        assertEquals("hard", readBack.gameVariables.get("difficulty"));
        
        temp.delete();
    }
    
}
