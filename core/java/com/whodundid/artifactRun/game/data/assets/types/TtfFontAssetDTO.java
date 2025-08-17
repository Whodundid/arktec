package com.whodundid.artifactRun.game.data.assets.types;

import com.badlogic.gdx.assets.AssetDescriptor;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.freetype.FreeTypeFontGenerator;
import com.badlogic.gdx.graphics.g2d.freetype.FreetypeFontLoader;
import com.whodundid.artifactRun.game.data.assets.AbstractGameAssetDTO;
import com.whodundid.artifactRun.game.data.assets.AssetLocation;
import com.whodundid.artifactRun.game.data.assets.AssetType;

public class TtfFontAssetDTO extends AbstractGameAssetDTO<BitmapFont> {
    
    //========
    // Fields
    //========
    
    /** logical key (required) */
    public String name;
    /** path to .ttf/.otf */
    public String filePath;
    public AssetLocation location = AssetLocation.INTERNAL;
    
    // generation params (common subset)
    public int size = 16;
    public boolean flip = false;
    public boolean mono = false;
    /** if null default to the LibGDX charset */
    public String characters = null;
    
    public boolean genMipMaps = false;
    public float borderWidth = 0f;
    /** hex "#RRGGBBAA" or "#RRGGBB" */
    public String borderColor = null;
    public int shadowOffsetX = 0;
    public int shadowOffsetY = 0;
    /** hex */
    public String shadowColor = null;
    
    //==============
    // Constructors
    //==============
    
    public TtfFontAssetDTO(
        String name,
        String filePath,
        AssetLocation location,
        int size,
        boolean flip,
        boolean mono,
        String characters,
        boolean genMipMaps,
        float borderWidth,
        String borderColor,
        int shadowOffsetX,
        int shadowOffsetY,
        String shadowColor
    ){
        super(AssetType.FONT_BITMAP);
        
        this.name = name;
        this.filePath = filePath;
        this.location = location;
        this.size = size;
        this.flip = flip;
        this.mono = mono;
        this.characters = characters;
        this.genMipMaps = genMipMaps;
        this.borderWidth = borderWidth;
        this.borderColor = borderColor;
        this.shadowOffsetX = shadowOffsetX;
        this.shadowOffsetY = shadowOffsetY;
        this.shadowColor = shadowColor;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public AssetDescriptor<BitmapFont> toDescriptor() {
        // The FreeType pipeline uses: AssetDescriptor<BitmapFont> with a
        // FreetypeFontLoader.FreeTypeFontLoaderParameter that points to the font file name (string path)
        FreetypeFontLoader.FreeTypeFontLoaderParameter p = new FreetypeFontLoader.FreeTypeFontLoaderParameter();
        p.fontFileName = fhs(location, filePath); // path string is fine here
        
        FreeTypeFontGenerator.FreeTypeFontParameter fp = new FreeTypeFontGenerator.FreeTypeFontParameter();
        fp.size = size;
        fp.flip = flip;
        fp.mono = mono;
        fp.genMipMaps = genMipMaps;
        if (characters != null) fp.characters = characters;
        
        if (borderWidth > 0f) {
            fp.borderWidth = borderWidth;
            if (borderColor != null) fp.borderColor = parseColor(borderColor, Color.BLACK);
        }
        if (shadowOffsetX != 0 || shadowOffsetY != 0) {
            fp.shadowOffsetX = shadowOffsetX;
            fp.shadowOffsetY = shadowOffsetY;
            if (shadowColor != null) fp.shadowColor = parseColor(shadowColor, Color.BLACK);
        }
        
        p.fontParameters = fp;
        
        // key is the logical name (lets you swap font files without touching code)
        return new AssetDescriptor<>(name, BitmapFont.class, p);
    }
    
    @Override
    public String assetKey() {
        return name;
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    private static Color parseColor(String hex, Color fallback) {
        try {
            // Accept #RRGGBB or #AARRGGBB
            String h = hex.startsWith("#") ? hex.substring(1) : hex;
            long v = Long.parseLong(h, 16);
            if (h.length() == 6) {
                int r = (int) ((v >> 16) & 0xFF);
                int g = (int) ((v >> 8) & 0xFF);
                int b = (int) (v & 0xFF);
                return new Color(r / 255f, g / 255f, b / 255f, 1f);
            }
            else if (h.length() == 8) {
                int a = (int) (v & 0xFF);
                int r = (int) ((v >> 24) & 0xFF);
                int g = (int) ((v >> 16) & 0xFF);
                int b = (int) ((v >> 8) & 0xFF);
                return new Color(r / 255f, g / 255f, b / 255f, a / 255f);
            }
        }
        catch (Exception ignored) {}
        return fallback;
    }
    
}
