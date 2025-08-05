package com.whodundid.artifactRun.game.data.region.components;

import java.awt.Point;

import com.whodundid.artifactRun.game.data.region.util.AbstractRegionComponent;
import com.whodundid.artifactRun.game.data.region.util.RegionComponentType;

import eutil.datatypes.util.EList;

public class RegionPositionsComponent extends AbstractRegionComponent {
    
    //===============
    // Static Fields
    //===============
    
    public static final RegionComponentType COMPONENT_TYPE = RegionComponentType.POSITIONS;
    
    //========
    // Fields
    //========
    
    public final EList<Point> worldPositions = EList.newList();
    
    //==============
    // Constructors
    //==============
    
    public RegionPositionsComponent(EList<Point> points) {
        super(COMPONENT_TYPE);
        
        worldPositions.addAll(points);
    }
    
    public RegionPositionsComponent(RegionPositionsComponent comp) {
        super(COMPONENT_TYPE);
        
        worldPositions.addAll(comp.worldPositions);
    }
    
    //===========
    // Overrides
    //===========
    
    @Override
    public RegionPositionsComponent copy() {
        return new RegionPositionsComponent(this);
    }
    
}
