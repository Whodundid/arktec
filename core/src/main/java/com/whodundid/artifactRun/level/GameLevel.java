package com.whodundid.artifactRun.level;

import com.whodundid.artifactRun.dir.GameLevelDirectory;
import com.whodundid.artifactRun.level.world.GameWorld;

import eutil.datatypes.util.EList;

public class GameLevel {
    
    //========
    // Fields
    //========
    
    private GameLevelDirectory levelDirectory;
    
    private final EList<GameWorld> levelWorlds = EList.newList();
    
}
