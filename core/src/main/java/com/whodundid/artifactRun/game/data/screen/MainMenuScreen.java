package com.whodundid.artifactRun.game.data.screen;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.utils.ScreenUtils;
import com.whodundid.artifactRun.ArtifactRun;
import com.whodundid.artifactRun.rendering.RenderUtils;

public class MainMenuScreen extends BaseScreen {
    
    private SpriteBatch batch;
    private BitmapFont font;

    public MainMenuScreen(ArtifactRun game) {
        super(game);
    }

    @Override
    public void show() {
        super.show();
        
        batch = new SpriteBatch();
        font = new BitmapFont();
    }

    @Override
    public void render(float delta) {
        ScreenUtils.clear(0.1f, 0.1f, 0.1f, 1);

        batch.begin();
        RenderUtils.drawStringC(batch, font, "TEST", midX, midY);
        batch.end();

        if (Gdx.input.isKeyJustPressed(Input.Keys.SPACE)) {
            System.out.println("LOLOL");
            //game.setScreen(new SomeOtherScreen(game)); // Swap screens here
        }
    }

    @Override
    public void dispose() {
        batch.dispose();
        font.dispose();
    }
}
