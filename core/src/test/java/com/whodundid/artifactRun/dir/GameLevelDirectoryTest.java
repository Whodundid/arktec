package com.whodundid.artifactRun.dir;

import static org.junit.jupiter.api.Assertions.*;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.file.Path;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class GameLevelDirectoryTest {

    @Test
    void createsCorrectStructure(@TempDir Path tempDir) throws IOException {
        File levelDir = tempDir.resolve("testSave1").toFile();
        GameLevelDirectory dir = new GameLevelDirectory(levelDir);

        assertTrue(dir.getLevelDir().exists());
        assertTrue(dir.getLevelInfoFile().exists());
        assertTrue(dir.getLevelSettingsFile().exists());

        assertTrue(dir.getLevelDataDir().exists());
        assertTrue(dir.getWorldsDir().exists());
        assertTrue(dir.getEntitiesDir().exists());
        assertTrue(dir.getTilesDir().exists());
        assertTrue(dir.getScriptsDir().exists());
        assertTrue(dir.getTextFilesDir().exists());
    }

    @Test
    void previewImageWriteAndCheck(@TempDir Path tempDir) throws IOException {
        GameLevelDirectory dir = new GameLevelDirectory(tempDir.toFile());

        assertFalse(dir.hasLevelPreviewImage());

        // Create a dummy image
        BufferedImage img = new BufferedImage(64, 64, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g = img.createGraphics();
        g.setColor(Color.RED);
        g.fillRect(0, 0, 64, 64);
        g.dispose();

        dir.createPreviewImage(img);
        assertTrue(dir.hasLevelPreviewImage());

        // Verify file actually readable
        BufferedImage loaded = ImageIO.read(dir.getLevelPreviewImageFile());
        assertNotNull(loaded);
        assertEquals(64, loaded.getWidth());
        assertEquals(64, loaded.getHeight());
    }

    @Test
    void throwsIfNullImage(@TempDir Path tempDir) throws IOException {
        GameLevelDirectory dir = new GameLevelDirectory(tempDir.toFile());
        assertThrows(NullPointerException.class, () -> dir.createPreviewImage(null));
    }

    @Test
    void throwsIfNullDir() {
        assertThrows(NullPointerException.class, () -> new GameLevelDirectory(null));
    }
    
}
