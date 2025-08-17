# Assets Module

Centralized, data-driven asset loading using **LibGDX AssetManager**.

- **Goal:** Keep runtime code free of file paths and loading details.
- **Pattern:** JSON → DTO → `AssetDescriptor` → `AssetManager`.
- **One `AssetManager`** for the entire game (shared/injected).


## Key Conventions

- **Textures / Sounds / Music / BitmapFonts**  
  - Keyed by their `FileHandle.path()` (e.g., `images/player.png`).
- **TTF Fonts & Shaders**  
  - Keyed by a **logical name** (e.g., `ui-16`, `basic`), so you can change files without changing code.

> If two bundles reference the same key, AssetManager ref-counts it and only loads once.

## Supported DTOs (fields vary by type)

### Texture (`TextureAssetDTO`)
- `filePath`, `location`
- `minFilter`, `magFilter`, `uWrap`, `vWrap`, `useMipMaps`

### Sound (`SoundAssetDTO`)
- `filePath`, `location`

### Music (`MusicAssetDTO`)
- `filePath`, `location`

### Shader (`ShaderAssetDTO`)
- `name` (logical key), `vertexPath`, `fragmentPath`, `location`
- `pedantic`, `failIfError`

### Bitmap Font (`BitmapFontAssetDTO`)
- `filePath`, `location`
- optional `name` alias (otherwise path is the key)

### TTF Font (`TtfFontAssetDTO`)
- `name` (logical key), `filePath`, `location`
- `size`, `flip`, `mono`, `characters`
- Styling: `genMipMaps`, `borderWidth`, `borderColor`, `shadowOffsetX/Y`, `shadowColor`

## One-Time Loader Installation

Install once at app init:

```java
void installLoaders(AssetManager am) {
    var resolver = new com.badlogic.gdx.assets.loaders.resolvers.InternalFileHandleResolver();

    // FreeType (TTF/OTF → BitmapFont)
    am.setLoader(com.badlogic.gdx.graphics.g2d.freetype.FreeTypeFontGenerator.class,
        new com.badlogic.gdx.graphics.g2d.freetype.FreeTypeFontGeneratorLoader(resolver));
    am.setLoader(com.badlogic.gdx.graphics.g2d.BitmapFont.class, ".ttf",
        new com.badlogic.gdx.graphics.g2d.freetype.FreetypeFontLoader(resolver));
    am.setLoader(com.badlogic.gdx.graphics.g2d.BitmapFont.class, ".otf",
        new com.badlogic.gdx.graphics.g2d.freetype.FreetypeFontLoader(resolver));

    // Shaders
    am.setLoader(com.badlogic.gdx.graphics.glutils.ShaderProgram.class,
        new com.badlogic.gdx.assets.loaders.ShaderProgramLoader(resolver));
}
