package com.whodundid.artifactRun.screen;

import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.utils.viewport.FitViewport;
import com.badlogic.gdx.utils.viewport.Viewport;
import com.whodundid.artifactRun.ArtifactRun;

public abstract class BaseScreen implements Screen {
    
    //========
    // Fields
    //========
    
    private Viewport viewport;
    private OrthographicCamera camera;
    
    protected final ArtifactRun game;
    protected float width, height; 
    protected float midX, midY;
    
    //==============
    // Constructors
    //==============
    
    public BaseScreen(ArtifactRun game) {
        this.game = game;
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public void show() {
        camera = new OrthographicCamera();
        viewport = new FitViewport(800, 600, camera);
    }
    
    @Override
    public void resize(int width, int height) {
        // if the viewport is null, cry, but exit..
        if (viewport == null) return;
        
        this.width = width;
        this.height = height;
        midX = width / 2f;
        midY = height / 2f;
        viewport.update(width, height, true);
    }
    
    @Override public void pause() {}
    @Override public void resume() {}
    @Override public void hide() {}
    @Override public void dispose() {}

}

