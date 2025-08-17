package com.whodundid.artifactRun.save;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.LinkedHashMap;
import java.util.Map;

import com.whodundid.artifactRun.io.json.JsonUtil;
import com.whodundid.artifactRun.settings.SettingKeys;

import eutil.EUtil;
import eutil.datatypes.util.EList;
import eutil.strings.EStringBuilder;
import eutil.strings.EStringUtil;

/**
 * Contains metadata info on the save.
 * <p>
 * These values are not really meant to be configurable by the player.
 * <p>
 * Instead this object holds information on the following:
 * <ol>
 *     <li>Save metadata:
 *         <ul>
 *             <li>Save Name</li>
 *             <li>Player List</li>
 *             <li>Game Version</li>
 *             <li>Creation and Playtime Data</li>
 *         </ul>
 *     </li>
 *     <li>Starting World</li>
 *     <li>Current Game Stage</li>
 *     <li>Persistent Game State Variables</li>
 * </ol>
 */
public class GameSaveInfo {
    
    //===============
    // Static Fields
    //===============
    
    public static final String DEFAULT_STARTING_WORLD = "NO_STARTING_WORLD";
    public static final String DEFAULT_CURRENT_GAME_STAGE = "NO_CURRENT_GAME_STAGE";
    
    //========
    // Fields
    //========
    
    /** The name of the level. */
    public String saveName;
    /** The people who are in the level. */
    public final EList<String> playerList = EList.newList();
    /** The version of the game that this save works with. #.#.# (expect major versions to be incompatible) */
    public String gameVersion;
    /** Save file creation time stamp. */
    public long creationTimestamp;
    /** Timestamp that the save was last played. */
    public long lastPlayedTimestamp;
    /** Total playtime timestamp. */
    public long totalPlaytimeTimestamp;
    /** The world to start on when loading the game. */
    public String startingWorld;
    /** The game's current game stage. Can be obfuscated -- just denotes the point in the game the player is at. */
    public String currentGameStage;
    /** Variables for the save file that carry across play sessions. All data can be obfuscated if desired. */
    public final Map<String, String> gameVariables = new LinkedHashMap<>();
    /** The hash of the starting world, game stage, and variables to ensure they're not messed with. */
    public String saveHash;
    
    //==============
    // Constructors
    //==============
    
    public GameSaveInfo(String saveName) {
        this.saveName = saveName;
    }
    
    public GameSaveInfo(
        String saveName,
        EList<String> playerList,
        String gameVersion,
        long creationTimestamp,
        long lastPlayedTimestamp,
        long totalPlaytimeTimestamp,
        String startingWorld,
        String currentGameStage,
        Map<String, String> levelVariables,
        String levelHash
    ){
        this.saveName = saveName;
        this.playerList.addAll(playerList);
        this.gameVersion = gameVersion;
        this.creationTimestamp = creationTimestamp;
        this.lastPlayedTimestamp = lastPlayedTimestamp;
        this.totalPlaytimeTimestamp = totalPlaytimeTimestamp;
        this.startingWorld = startingWorld;
        this.currentGameStage = currentGameStage;
        this.gameVariables.putAll(levelVariables);
        this.saveHash = levelHash;
    }
    
    //=========
    // Methods
    //=========
    
    public void saveLevelFile(File fileToSaveTo) throws IOException {
        updateLastPlayedTime();
        this.saveHash = createLevelHash();
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
        return EUtil.isEqual(computedHash, saveHash);
    }
    
    public void writeLevelVariable(String variableName, Object value) {
        if (EStringUtil.isNotPopulated(variableName)) {
            throw new IllegalArgumentException("Cannot write an empty variable to the level!");
        }
        
        gameVariables.put(variableName, String.valueOf(value));
    }
    
    public void removeLevelVariable(String variableName) {
        if (EStringUtil.isNotPopulated(variableName)) {
            throw new IllegalArgumentException("Cannot remove an empty variable name from the level!");
        }
        
        gameVariables.remove(variableName);
    }
    
    public void assignCreationTime() {
        long current = System.currentTimeMillis();
        creationTimestamp = current;
    }
    
    public void updateLastPlayedTime() {
        long current = System.currentTimeMillis();
        lastPlayedTimestamp = current;
    }
    
    public boolean isHardcoreModeSet() {
        if (!gameVariables.containsKey(SettingKeys.HARDCORE_MODE)) return false;
        String value = gameVariables.get(SettingKeys.HARDCORE_MODE);
        return Boolean.parseBoolean(value);
    }
    
    public boolean isCheatModeSet() {
        if (!gameVariables.containsKey(SettingKeys.CHEAT_MODE)) return false;
        String value = gameVariables.get(SettingKeys.CHEAT_MODE);
        return Boolean.parseBoolean(value);
    }
    
    //=========================
    // Internal Helper Methods
    //=========================
    
    protected String createLevelHash() {
        var sb = new EStringBuilder();
        sb.a(startingWorld != null ? startingWorld : DEFAULT_STARTING_WORLD);
        sb.a(currentGameStage != null ? currentGameStage : DEFAULT_CURRENT_GAME_STAGE);
        for (var e : gameVariables.entrySet()) {
            String key = e.getKey();
            String value = e.getValue();
            sb.a(key, value);
        }
        return createHashString(sb.toString());
    }
    
    //=======================
    // Static Helper Methods
    //=======================
    
    public static GameSaveInfo parseLevelFileJson(File jsonFile) throws IOException {
        Path jsonFilePath = jsonFile.toPath();
        String json = Files.readString(jsonFilePath);
        return parseLevelFileJson(json);
    }
    
    public static GameSaveInfo parseLevelFileJson(String json) {
        return JsonUtil.fromJson(json, GameSaveInfo.class);
    }
    
    public static String createHashString(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashedBytes = digest.digest(input.getBytes());
            
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
    
}
