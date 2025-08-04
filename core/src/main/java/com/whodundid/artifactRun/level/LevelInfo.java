package com.whodundid.artifactRun.level;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.LinkedHashMap;
import java.util.Map;

import com.whodundid.artifactRun.json.JsonUtil;

import eutil.EUtil;
import eutil.datatypes.util.EList;
import eutil.strings.EStringBuilder;

public class LevelInfo {
    
    //===============
    // Static Fields
    //===============
    
    public static final String DEFAULT_STARTING_WORLD = "NO_STARTING_WORLD";
    public static final String DEFAULT_CURRENT_GAME_STAGE = "NO_CURRENT_GAME_STAGE";
    
    //========
    // Fields
    //========
    
    /** The name of the level. */
    public String levelName;
    /** The people who are in the level. */
    public final EList<String> playerList = EList.newList();
    /** The verison of this level -- user made -- can be whatever. */
    public String levelVersion;
    /** The version of the game that this level works with. #.#.# (expect major versions to be incompatible) */
    public String gameVersion;
    /** Level creation time stamp. */
    public long creationTimestamp;
    /** Timestamp that the level was last played. */
    public long lastPlayedTimestamp;
    /** The world to start on when loading the game. */
    public String startingWorld;
    /** The game's current game stage. Can be obfuscated -- just denotes the point in the game the player is at. */
    public String currentGameStage;
    /** Variables for the level that carry across play sessions. All data can be obfuscated if desired. */
    public final Map<String, String> levelVariables = new LinkedHashMap<>();
    /** The hash of the starting world, game stage, and variables to ensure they're not messed with. */
    public String levelHash;
    
    //==============
    // Constructors
    //==============
    
    public LevelInfo(String levelName) {
        this.levelName = levelName;
    }
    
    public LevelInfo(
        String levelName,
        EList<String> playerList,
        String levelVersion,
        String gameVersion,
        long creationTimestamp,
        long lastPlayedTimestamp,
        String startingWorld,
        String currentGameStage,
        Map<String, String> levelVariables,
        String levelHash
    ){
        this.levelName = levelName;
        this.playerList.addAll(playerList);
        this.levelVersion = levelVersion;
        this.gameVersion = gameVersion;
        this.creationTimestamp = creationTimestamp;
        this.lastPlayedTimestamp = lastPlayedTimestamp;
        this.startingWorld = startingWorld;
        this.currentGameStage = currentGameStage;
        this.levelVariables.putAll(levelVariables);
        this.levelHash = levelHash;
    }
    
    //=========
    // Methods
    //=========
    
    public void saveLevelFile(File fileToSaveTo) throws IOException {
        this.levelHash = createLevelHash();
        String json = toJson();
        Files.write(fileToSaveTo.toPath(), json.getBytes());
    }
    
    public String toJson() {
        return JsonUtil.toPrettyJson(this);
    }
    
    /**
     * Checks if the level hash in the loaded level file matches the expected
     * computed hash value.
     * <p>
     * Used to detect if the level file has been modified outside of the game!
     * 
     * @return True if the level hash file is valid
     */
    public boolean isLevelHashValid() {
        String computedHash = createLevelHash();
        // handle the case where the hash fails -- for some reason
        if (computedHash == null) return false;
        // check if the loaded and computed values match
        return EUtil.isEqual(computedHash, levelHash);
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    protected String createLevelHash() {
        try {
            var sb = new EStringBuilder();
            sb.a(startingWorld != null ? startingWorld : DEFAULT_STARTING_WORLD);
            sb.a(currentGameStage != null ? currentGameStage : DEFAULT_CURRENT_GAME_STAGE);
            for (var e : levelVariables.entrySet()) {
                String key = e.getKey();
                String value = e.getValue();
                sb.a(key, value);
            }
            String values = sb.toString();
            
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashedBytes = digest.digest(values.getBytes());
            
            // map to hex string for easier storage
            var hexString = new EStringBuilder();
            for (byte b : hashedBytes) {
                hexString.a(String.format("%02x", b));
            }
            
            return hexString.toString();
        }
        catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
            return null;
        }
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static LevelInfo parseLevelFileJson(File jsonFile) throws IOException {
        Path jsonFilePath = jsonFile.toPath();
        String json = Files.readString(jsonFilePath);
        return parseLevelFileJson(json);
    }
    
    public static LevelInfo parseLevelFileJson(String json) {
        return JsonUtil.fromJson(json, LevelInfo.class);
    }
    
}
