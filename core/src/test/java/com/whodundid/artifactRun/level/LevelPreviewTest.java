package com.whodundid.artifactRun.level;

import static org.junit.jupiter.api.Assertions.*;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;

import com.whodundid.artifactRun.dir.GameLevelDirectory;

import eutil.file.EFileUtil;

class LevelPreviewTest {
    
    @Test
    void testNoImageAvailable() throws IOException {
        // Setup a fake GameLevel with no preview image
        DummyGameLevel level = new DummyGameLevel(false);
        LevelPreview preview = new LevelPreview(level);
        
        preview.load();
        assertFalse(preview.isPreviewLoaded());
        assertNull(preview.getPreviewImage());
        
        level.delete();
    }
    
    @Test
    void testImageLoading() throws IOException {
        // Create a dummy PNG image file
        File previewFile = File.createTempFile("test_preview", ".png");
        BufferedImage image = new BufferedImage(64, 64, BufferedImage.TYPE_INT_ARGB);
        Graphics2D g2d = image.createGraphics();
        g2d.setColor(Color.RED);
        g2d.fillRect(0, 0, 64, 64);
        g2d.dispose();
        ImageIO.write(image, "png", previewFile);
        
        // Setup GameLevel with stubbed preview path
        DummyGameLevel level = new DummyGameLevel(true, previewFile);
        LevelPreview preview = new LevelPreview(level);
        
        preview.load();
        assertTrue(preview.isPreviewLoaded());
        assertNotNull(preview.getPreviewImage());
        assertEquals(64, preview.getPreviewImage().getWidth());
        
        previewFile.delete();
        level.delete();
    }
    
    // Dummy stub classes to fake GameLevel behavior
    
    static class DummyGameLevel extends GameLevel {
        GameLevelDirectory dir;
        
        DummyGameLevel(boolean hasImage) throws IOException {
            this(hasImage, null);
        }
        DummyGameLevel(boolean hasImage, File file) throws IOException {
            super(new DummyLevelDirectory(hasImage, file));
            this.dir = this.getLevelDirectory();
        }
        
        void delete() {
            EFileUtil.deleteDirectory(dir.getLevelDir());
        }
    }
    
    static class DummyLevelDirectory extends GameLevelDirectory {
        private final boolean hasImage;
        private final File imageFile;
        
        DummyLevelDirectory(boolean hasImage, File imageFile) throws IOException {
            super(new File("unused"));
            this.hasImage = hasImage;
            this.imageFile = imageFile;
        }
        
        @Override
        public boolean hasLevelPreviewImage() {
            return hasImage;
        }
        
        @Override
        public File getLevelPreviewImageFile() {
            return imageFile;
        }
    }
    
}
