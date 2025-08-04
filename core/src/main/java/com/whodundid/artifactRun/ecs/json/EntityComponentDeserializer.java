package com.whodundid.artifactRun.ecs.json;

import java.lang.reflect.Type;

import com.google.gson.JsonDeserializationContext;
import com.google.gson.JsonDeserializer;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.whodundid.artifactRun.ecs.EntityComponentRegistry;
import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;

public class EntityComponentDeserializer implements JsonDeserializer<AbstractEntityComponent> {
    
    @Override
    public AbstractEntityComponent deserialize(JsonElement json, Type typeOfT, JsonDeserializationContext context) throws JsonParseException {
        JsonObject obj = json.getAsJsonObject();
        String type = obj.get("type").getAsString();

        Class<? extends AbstractEntityComponent> clazz = EntityComponentRegistry.get(type);
        if (clazz == null) {
            throw new JsonParseException("Unknown component type: " + type);
        }

        return context.deserialize(json, clazz);
    }
    
}
