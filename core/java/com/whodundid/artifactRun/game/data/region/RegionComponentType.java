package com.whodundid.artifactRun.game.data.region;

public enum RegionComponentType {
    /** Region name. */
    NAME,
    /** Holds a list of world grid points that make up the region's bounds. */
    POSITIONS,
    /** Fire on enter. */
    ENTITY_ENTERED_TRIGGER,
    /** Fire on exit. */
    ENTITY_EXITED_TRIGGER,
    /** Apply/Remove status effect from all entities within region. */
    STATUS_EFFECT,
    /** Sound effects of certain types will play in these regions. */
    ENVIRONMENT_SOUNDS,
    /** Faction owner. */
    FACTION_OWNER,
}
