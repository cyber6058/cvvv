//
//  SurveyStationEntity.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/1/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import Foundation
import RealityKit /// basically everything here
import UIKit /// for UIColor
import ARKit

class SurveyStationEntity: Entity, HasAnchoring, HasModel, HasCollision {
    
    static let defaultRadius: Float = 0.01
    static let defaultColor: UIColor = .gray
    
    var bbox_loc: String = ""
    var RayQuery: ARRaycastQuery?
    var sphere: ModelEntity!
    var ori_color: UIColor
    var highlighted: Bool
    
    init(worldTransform: float4x4?, bbox_loc: String = "", RayQuery: ARRaycastQuery?, station_defect_type: String = "", ARscene: Scene) { //} , image: CVImageBuffer? = nil) {
        
        self.RayQuery = RayQuery
        self.highlighted = false
    

        var station_color = SurveyStationEntity.defaultColor
        
        
        //concrete cracks, exposed rebar, paint bubbles, paint cracks, and paint peeling
        print("Isaac ##Debug surver staion enity \(station_defect_type)")
        if station_defect_type.contains("exposed rebar")  {station_color = UIColor(red: 1, green: 0, blue: 0, alpha: 1)}
        if station_defect_type.contains("paint peeling")  {station_color = UIColor(red: 0, green: 1, blue: 0, alpha: 1)}
        if station_defect_type.contains("paint bubble")         {station_color = UIColor(red: 0, green: 0, blue: 1, alpha: 1)}
        if station_defect_type.contains("paint crack")    {station_color = UIColor(red: 1, green: 1, blue: 0, alpha: 1)}
        if station_defect_type.contains("concrete crack")  {station_color = UIColor(red: 0, green: 1, blue: 1, alpha: 1)}
    
        self.ori_color = station_color
        
        super.init()
        self.collision = CollisionComponent(shapes: [ ShapeResource.generateSphere( radius: SurveyStationEntity.defaultRadius)])
        //@Isaac Change the generated shape
        
        let mesh = MeshResource.generateSphere(radius: SurveyStationEntity.defaultRadius) // Original sphere
//        let mesh = MeshResource.generatePlane(width: 0.05, height: 0.10) //If height -> parallel to ground
//        let mesh = MeshResource.generatePlane(width: 0.05, depth: 0.10) //If depth -> parallel to wall
//        let mesh = MeshResource.generateBox(width: 0.5, height: 0.01, depth: 0.10, cornerRadius: 0, splitFaces: false) //3D generation
        
        
        let materials = [SimpleMaterial(color: station_color,isMetallic: false)]

        self.sphere = ModelEntity(mesh: mesh, materials: materials)
        self.bbox_loc = bbox_loc

        addChild(self.sphere!)
        
        if let world_Transform = worldTransform{
            self.transform.matrix = worldTransform!
        }
        
//        ARscene.addAnchor(self)
        
//        self.cap_img = image
//        self.cam_worldTransform = worldTransform
        
//        print("SurveyStationEntity inti \(self.isAnchored)")
        
        
        //TODO: add camera transform
    }

    
    
    required init() {
        fatalError("init() has not been implemented")
    }

    func highlight(_ doHighlight: Bool) {
        
        if self.highlighted {
            let color: UIColor = ori_color
            print("highlighted: \(self.highlighted), color: \(color)")

            self.sphere.model?.materials[0] = SimpleMaterial(color: color, isMetallic: false)
            
            self.highlighted = false
        }
        else{
            let color: UIColor = .gray
            print("highlighted: \(self.highlighted), color: \(color)")

            self.sphere.model?.materials[0] = SimpleMaterial(color: color, isMetallic: false)
            self.highlighted = true
        }
        
//        if self.sphere.model?.materials.col
//        let color: UIColor = doHighlight ? .gray : ori_color
        
        
    }

    func lineTo(_ other: SurveyStationEntity, linked_bbox_loc: String) -> SurveyLineEntity {
        
        print("DEBUG Line naming 1: survey station lineTO() linked_bbox_loc: \(linked_bbox_loc)")
        return SurveyLineEntity(start: self, end: other, linked_bbox_loc: linked_bbox_loc)
    }
}
