package com.whodundid.artifactRun.ecs;

public interface EntityComponent {
    
    String getTypeName();
    
    EntityComponent copy();
    
}
