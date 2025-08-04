package com.whodundid.artifactRun.ecs.json;

import java.lang.reflect.Type;
import java.util.Map;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonSerializationContext;
import com.google.gson.JsonSerializer;
import com.whodundid.artifactRun.ecs.util.AbstractEntityComponent;

public class EntityComponentSerializer implements JsonSerializer<AbstractEntityComponent> {
    
    @Override
    public JsonElement serialize(AbstractEntityComponent src, Type typeOfSrc, JsonSerializationContext context) {
        JsonObject original = context.serialize(src).getAsJsonObject();
        JsonObject result = new JsonObject();

        result.addProperty("type", src.getComponentType().name());

        for (Map.Entry<String, JsonElement> entry : original.entrySet()) {
            result.add(entry.getKey(), entry.getValue());
        }

        return result;
    }
    
}
