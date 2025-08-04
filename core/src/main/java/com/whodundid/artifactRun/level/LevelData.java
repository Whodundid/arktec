package com.whodundid.artifactRun.level;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

import com.whodundid.artifactRun.ecs.Entity;
import com.whodundid.artifactRun.scripts.GameScript;
import com.whodundid.artifactRun.world.GameWorld;
import com.whodundid.artifactRun.world.tile.WorldTile;

import eutil.datatypes.boxes.BoxList;
import eutil.datatypes.util.EList;
import eutil.strings.EStringBuilder;
import eutil.strings.EStringUtil;

public class LevelData {
    
    //========
    // Fields
    //========
    
    /** The level for which this data pertains to. */
    private final GameLevel level;
    
    private LevelInfo levelFile;
    
    private final EList<Entity> loadedEntities = EList.newList();
    private final EList<WorldTile> loadedWorldTiles = EList.newList();
    private final EList<GameWorld> loadedWorlds = EList.newList();
    private final EList<GameScript> loadedScripts = EList.newList();
    
    private boolean isLoaded;
    private boolean isLevelValid;
    
    //==============
    // Constructors
    //==============
    
    public LevelData(GameLevel level) {
        this.level = level;
    }
    
    //=========
    // Methods
    //=========
    
    public void load() throws IOException {
        isLoaded = false;
        
        var dir = level.getLevelDirectory();
        
        levelFile = LevelInfo.parseLevelFileJson(dir.getLevelInfoFile());
        isLevelValid = levelFile.isLevelHashValid();
        
        File entitiesDir = dir.getEntitiesDir();
        File worldTilesDir = dir.getTilesDir();
        File worldsDir = dir.getWorldsDir();
        File scriptsDir = dir.getScriptsDir();
        
        var problemEntities = loadEntities(entitiesDir);
        var problemTiles = loadWorldTiles(worldTilesDir);
        var problemWorlds = loadGameWorlds(worldsDir);
        var problemScripts = loadScripts(scriptsDir);
        
        displayProblemFiles(problemEntities);
        displayProblemFiles(problemTiles);
        displayProblemFiles(problemWorlds);
        displayProblemFiles(problemScripts);
        
        isLoaded = true;
    }
    
    public void save() throws IOException {
        var dir = level.getLevelDirectory();
        
        updateLastPlayedTime();
        levelFile.saveLevelFile(dir.getLevelInfoFile());
    }
    
    public void writeLevelVariable(String variableName, Object value) {
        if (EStringUtil.isNotPopulated(variableName)) {
            throw new IllegalArgumentException("Cannot write an empty variable to the level!");
        }
        
        levelFile.levelVariables.put(variableName, String.valueOf(value));
    }
    
    public void removeLevelVariable(String variableName) {
        if (EStringUtil.isNotPopulated(variableName)) {
            throw new IllegalArgumentException("Cannot remove an empty variable name from the level!");
        }
        
        levelFile.levelVariables.remove(variableName);
    }
    
    public void assignCreationTime() {
        long current = System.currentTimeMillis();
        levelFile.creationTimestamp = current;
    }
    
    public void updateLastPlayedTime() {
        long current = System.currentTimeMillis();
        levelFile.lastPlayedTimestamp = current;
    }
    
    //==================
    // Internal Methods
    //==================
    
    protected BoxList<File, Throwable> loadEntities(File entitiesDir) {
        loadedEntities.clear();
        
        BoxList<File, Throwable> problemFiles = BoxList.newList();
        
        // load each file in the directory
        for (File entFile : getJsonFiles(entitiesDir)) {
            // only try to load json files
            if (!entFile.getPath().endsWith(".json")) continue;
            
            try {
                Path entFilePath = entFile.toPath();
                String jsonString = Files.readString(entFilePath);
                
                Entity ent = Entity.fromJson(jsonString);
                loadedEntities.add(ent);
            }
            catch (Exception e) {
                problemFiles.add(entFile, e);
            }
        }
        
        return problemFiles;
    }
    
    protected BoxList<File, Throwable> loadWorldTiles(File worldTilesDir) {
        loadedWorldTiles.clear();
        
        BoxList<File, Throwable> problemFiles = BoxList.newList();
        
        // load each file in the directory
        for (File tileFile : getJsonFiles(worldTilesDir)) {
            // only try to load json files
            if (!tileFile.getPath().endsWith(".json")) continue;
            
            try {
                Path entFilePath = tileFile.toPath();
                String jsonString = Files.readString(entFilePath);
                
                WorldTile ent = WorldTile.fromJson(jsonString);
                loadedWorldTiles.add(ent);
            }
            catch (Exception e) {
                problemFiles.add(tileFile, e);
            }
        }
        
        return problemFiles;
    }
    
    protected BoxList<File, Throwable> loadGameWorlds(File worldDir) {
        loadedWorlds.clear();
        
        BoxList<File, Throwable> problemFiles = BoxList.newList();
        
        // ...
        
        return problemFiles;
    }
    
    protected BoxList<File, Throwable> loadScripts(File scriptsDir) {
        loadedScripts.clear();
        
        BoxList<File, Throwable> problemFiles = BoxList.newList();
        
        // ...
        
        return problemFiles;
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    protected static void displayProblemFiles(BoxList<File, Throwable> problemFiles) {
        if (problemFiles == null || problemFiles.isEmpty()) return;
        
        for (var b : problemFiles) {
            File f = b.getA();
            Throwable t = b.getB();
            
            String errorString = formatProblemFile(f, t);
            System.err.println(errorString);
            t.printStackTrace();
        }
    }
    
    protected static String formatProblemFile(File file, Throwable error) {
        var sb = new EStringBuilder();
        sb.a("Error loading file: '", file, "'");
        sb.a(" reason: ", error);
        return sb.toString();
    }
    
    protected static List<File> getJsonFiles(File dir) {
        return Arrays.stream(dir.listFiles())
                     .filter(f -> f.getName().endsWith(".json"))
                     .toList();
    }

    
    //=========
    // Getters
    //=========
    
    public boolean isLoaded() { return isLoaded; }
    public boolean isLevelValid() { return isLevelValid; }
    
    public EList<Entity> getLoadedEntities() { return loadedEntities; }
    public EList<WorldTile> getLoadedWorldTiles() { return loadedWorldTiles; }
    public EList<GameWorld> getLoadedGameWorlds() { return loadedWorlds; }
    public EList<GameScript> getLoadedScripts() { return loadedScripts; }
    
    public LevelInfo getLevelFile() { return levelFile; }
    
    // wrapped from LevelFile
    public String getLevelName() { return levelFile.levelName; }
    public EList<String> getLevelPlayers() { return levelFile.playerList; }
    public String getLevelVersion() { return levelFile.levelVersion; }
    public String getGameVersion() { return levelFile.gameVersion; }
    public String getStartingWorld() { return levelFile.startingWorld; }
    public String getCurrentGameStage() { return levelFile.currentGameStage; }
    public Map<String, String> getLevelVariables() { return levelFile.levelVariables; }
    public String getLevelHash() { return levelFile.levelHash; }
    
}
