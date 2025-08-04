package com.whodundid.artifactRun.ecs.util;

import java.lang.reflect.Type;

import com.google.gson.InstanceCreator;

import eutil.datatypes.EArrayList;
import eutil.datatypes.util.EList;

public class EListInstanceCreator implements InstanceCreator<EList<?>> {
    
    @Override
    public EList<?> createInstance(Type type) {
        return new EArrayList<>();
    }
    
}
