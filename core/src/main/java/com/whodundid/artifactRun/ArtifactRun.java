package com.whodundid.artifactRun;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.whodundid.artifactRun.screen.MainMenuScreen;

public class ArtifactRun extends Game {
    
    private SpriteBatch batch;
    
    @Override
    public void create() {
        batch = new SpriteBatch();
        setScreen(new MainMenuScreen(this));
    }
    
    @Override
    public void dispose() {
        super.dispose();
        batch.dispose();
    }
    
}
