package com.whodundid.artifactRun.json;

import java.lang.reflect.Type;

import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.whodundid.artifactRun.game.data.tiles.WorldTileComponentRegistry;
import com.whodundid.artifactRun.game.data.tiles.util.AbstractWorldTileComponent;

public class WorldTileComponentDeserializer implements JsonDeserializer<AbstractWorldTileComponent> {
    
    @Override
    public AbstractWorldTileComponent deserialize(JsonElement json, Type typeOfT, JsonDeserializationContext context) throws JsonParseException {
        JsonObject obj = json.getAsJsonObject();
        String type = obj.get("type").getAsString();

        Class<? extends AbstractWorldTileComponent> clazz = WorldTileComponentRegistry.get(type);
        if (clazz == null) {
            throw new JsonParseException("Unknown component type: " + type);
        }

        return context.deserialize(json, clazz);
    }
    
}
