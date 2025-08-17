package com.whodundid.artifactRun.io.json;

import java.lang.reflect.Type;
import java.util.Map;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonSerializationContext;
import com.google.gson.JsonSerializer;
import com.whodundid.artifactRun.game.component.tile.AbstractWorldTileComponent;

public class WorldTileComponentSerializer implements JsonSerializer<AbstractWorldTileComponent> {
    
    @Override
    public JsonElement serialize(AbstractWorldTileComponent src, Type typeOfSrc, JsonSerializationContext context) {
        JsonObject original = context.serialize(src).getAsJsonObject();
        JsonObject result = new JsonObject();
        
        result.addProperty("type", src.getComponentType().name());
        
        for (Map.Entry<String, JsonElement> entry : original.entrySet()) {
            result.add(entry.getKey(), entry.getValue());
        }
        
        return result;
    }
    
}
