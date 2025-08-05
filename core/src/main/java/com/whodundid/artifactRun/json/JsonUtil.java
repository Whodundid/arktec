package com.whodundid.artifactRun.json;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonSyntaxException;
import com.whodundid.artifactRun.game.data.ecs.util.AbstractEntityComponent;
import com.whodundid.artifactRun.game.data.tiles.util.AbstractWorldTileComponent;

import eutil.datatypes.util.EList;

public class JsonUtil {
    
    //===============
    // Static Fields
    //===============
    
    public static final Gson GSON = new GsonBuilder()
        .registerTypeAdapter(AbstractEntityComponent.class, new EntityComponentDeserializer())
        .registerTypeAdapter(AbstractEntityComponent.class, new EntityComponentSerializer())
        .registerTypeAdapter(AbstractWorldTileComponent.class, new WorldTileComponentDeserializer())
        .registerTypeAdapter(AbstractWorldTileComponent.class, new WorldTileComponentSerializer())
        .registerTypeAdapter(EList.class, new EListInstanceCreator())
        .enableComplexMapKeySerialization()
        .setPrettyPrinting()
        .create();
    
    //================
    // Static Methods
    //================
    
    public static String indentJson(String input) {
        if (input == null) return null;
        
        Pattern pattern = Pattern.compile("(?m)^ +");
        Matcher matcher = pattern.matcher(input);
        
        return matcher.replaceAll(match -> " ".repeat(match.group().length() * 2));
    }
    
    public static String toJson(Object in) {
        return GSON.toJson(in);
    }
    
    public static String toPrettyJson(Object in) {
        String s = toJson(in);
        return indentJson(s);
    }
    
    public static <T> T fromJson(String json, Class<T> classOfT) throws JsonSyntaxException {
        return GSON.fromJson(json, classOfT);
    }
    
}
