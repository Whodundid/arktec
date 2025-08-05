package com.whodundid.artifactRun.game.dir;

import static org.junit.jupiter.api.Assertions.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class GameRootDirectoryTest {

    @Test
    void createsCorrectStructure(@TempDir Path tempDir) throws IOException {
        File root = tempDir.resolve("artifactRun").toFile();
        GameRootDirectory dir = new GameRootDirectory(root);

        assertTrue(dir.getRootGameDir().exists());
        assertTrue(dir.getAssetsDir().exists());
        assertTrue(dir.getSavesDir().exists());
        assertTrue(dir.getConfigDir().exists());
        assertTrue(dir.getLogsDir().exists());

        assertTrue(dir.getTexturesDir().exists());
        assertTrue(dir.getSoundsDir().exists());
        assertTrue(dir.getMusicDir().exists());
        assertTrue(dir.getFontsDir().exists());
        assertTrue(dir.getShadersDir().exists());
    }

    @Test
    void throwsIfNullRoot() {
        assertThrows(NullPointerException.class, () -> new GameRootDirectory(null));
    }
    
}
