package com.whodundid.artifactRun.ecs;

public interface IEntityComponent {
    
    String getTypeName();
    
    IEntityComponent copy();
    
}
