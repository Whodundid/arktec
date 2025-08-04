package com.whodundid.artifactRun.util;

import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;

public class RenderUtils {
    
    private static final GlyphLayout layout = new GlyphLayout();
    
    public static void drawStringC(SpriteBatch batch, BitmapFont font, String text, float x, float y) {
        drawStringCentered(batch, font, text, x, y);
    }
    
    public static void drawStringCentered(SpriteBatch batch, BitmapFont font, String text, float x, float y) {
        layout.setText(font, text);
        float textWidth = layout.width;
        float textHeight = layout.height;

        // Remember: y is baseline by default, so we add height to center it vertically
        font.draw(batch, layout, x - textWidth / 2f, y + textHeight / 2f);
    }
    
}
