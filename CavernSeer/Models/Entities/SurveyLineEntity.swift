//
//  SurveyLineEntity.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/4/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import Foundation
import RealityKit /// Entity, HasAnchoring, ARView
import ARKit /// CG*

class SurveyLineEntity: Entity, HasAnchoring, Drawable {

    /// entity the line starts at
    var start: Entity
    /// entity the line ends at
    var end: Entity

    /// projection of `start`'s position onto the view
    var startProjection: CGPoint?
    /// projection of `end`'s position onto the view
    var endProjection: CGPoint?
    
    var linked_bbox_loc: String

    init(start: Entity, end: Entity, linked_bbox_loc: String) {
        self.start = start
        self.end = end
        self.linked_bbox_loc = linked_bbox_loc
        
        print("DEBUG Line naming 2: SurveyLineEntity init() linked_bbox_loc: \(self.linked_bbox_loc)")
        
        super.init()
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    func updateProjections(arView: ARView) {
        guard
            let startAnchor = start.anchor,
            let endAnchor = end.anchor,
            let startProj = arView.project(startAnchor.position),
            let endProj = arView.project(endAnchor.position)
        else {
            return
        }
        
//        print(startAnchor.parent?.t)
        
        self.startProjection = startProj
        self.endProjection = endProj
    }

    func prepareToDraw(arView: ARView) {
        updateProjections(arView: arView)
    }

    func draw(context: CGContext) {
        guard
            let startProj = startProjection,
            let endProj = endProjection
        else {
            return
        }

        context.beginPath()
        context.move(to: startProj)
        context.addLine(to: endProj)
        context.strokePath()
        
//        print("Drawwww")
    }
}
