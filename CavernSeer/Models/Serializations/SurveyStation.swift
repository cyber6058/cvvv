//
//  SurveyStation.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/4/20.
//  Copyright © 2020 Samuel K. Grush. All rights reserved.
//

import Foundation
import ARKit /// float4x4, UIColor, SCN*
import SwiftUI

final class SurveyStation: NSObject, NSSecureCoding {
    typealias Identifier = UUID
    static var supportsSecureCoding: Bool { true }
    
    
    let name: String
    let identifier: Identifier
    let transform: float4x4
//    let cap_img: CVPixelBuffer?
//    let cam_loc: SIMD3<Float>

    init(entity: SurveyStationEntity, name: String) {
        guard
            let anchor = entity.anchor,
            let identifier = anchor.anchorIdentifier
                
        else {
            fatalError("SurveyStationEntity has no anchor")
        }
        
        print("SurveyStation-init(entity: SurveyStationEntity, name: String? = nil")

        self.name = name //?? identifier.uuidString
        self.identifier = identifier
        self.transform = entity.transform.matrix
//        self.cap_img = entity.cap_img
//        self.cam_loc = entity.cam_worldTransform
    }

    init(rename other: SurveyStation, to: String) {

        self.name = to
        self.identifier = other.identifier
        self.transform = other.transform
//        self.cap_img = other.cap_img
//        self.cam_loc = other.cam_loc
    }

    required init?(coder decoder: NSCoder) {
//        print("SurveyStation-init(entity: SurveyStationEntity, name: String? = nil")
        
//        self.cam_loc = SIMD3(0, 0, 0)
//        self.cap_img = nil
        
        self.identifier = decoder.decodeObject(
            of: NSUUID.self,
            forKey: PropertyKeys.identifier)! as Identifier
        
        self.transform = decoder.decode_simd_float4x4(prefix: PropertyKeys.transform)
        
        if decoder.containsValue(forKey: PropertyKeys.name) {
            self.name = decoder.decodeObject(
                of: NSString.self,
                forKey: PropertyKeys.name
            )! as String
        } else {
            self.name = self.identifier.uuidString
        }
    }

    func encode(with coder: NSCoder) {
        coder.encode(identifier as NSUUID, forKey: PropertyKeys.identifier)
        
//        coder.encode(cap_img! as CVPixelBuffer, forKey: PropertyKeys.cap_img)
        
        coder.encode(transform, forPrefix: PropertyKeys.transform)
        
        if name != identifier.uuidString {
            coder.encode(name as NSString, forKey: PropertyKeys.name)
        }
        
    }
}

extension SurveyStation {
    func toSCNNode() -> SCNNode? {
        let geo = SCNSphere(radius: 0.05) //0.03)
        let material = SCNMaterial()
        material.isDoubleSided = false //false
        material.lightingModel = .constant
//        material.diffuse.contents = UIColor.cyan
        
        material.diffuse.contents = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        
        
//        if self.name.contains("exposed rebar")  {material.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 1)}
//        if self.name.contains("paint peeling")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 1)}
//        if self.name.contains("bubble")         {material.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 1)}
//        if self.name.contains("paint crack")    {material.diffuse.contents = UIColor(red: 1, green: 1, blue: 0, alpha: 1)}
//        if self.name.contains("slender crack")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 1, alpha: 1)}
        
        
        if self.name.contains("oncrete")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 1, alpha: 0.9)}
        if self.name.contains("rebar")  {material.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 0.9)}
        if self.name.contains("bubble")         {material.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 0.9)}
        if self.name.contains("aint")    {material.diffuse.contents = UIColor(red: 1, green: 1, blue: 0, alpha: 0.9)}
        if self.name.contains("peeling")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 0.9)}
        
        
        geo.materials = [material]
        
//        print("#DEBUG SurveyStation to SCNNode: Orange")

        let node = SCNNode(geometry: geo)
//        node.name = self.name
        node.name = self.name + "_station"
        node.simdTransform = self.transform
        
        //For 4th EEEV
        
        var pos = node.position
        
//        node.position = SCNVector3(x: pos.x + 50  , y: pos.y + 50    , z: pos.z + 50)


        // Validation

//        if 1...2 ~= Int(self.name.split(separator: "_")[0])!   { node.position = SCNVector3(x: pos.x        , y: pos.y       , z: pos.z + 0.05) }
//
//        if 3...5 ~= Int(self.name.split(separator: "_")[0])!   { node.position = SCNVector3(x: pos.x - 0.05 , y: pos.y       , z: pos.z) }
//
//        if 8...10 ~= Int(self.name.split(separator: "_")[0])!  { node.position = SCNVector3(x: pos.x - 3.5  , y: pos.y       , z: pos.z + 10.5) }
//
//        if 11...12 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x        , y: pos.y - 0.1 , z: pos.z + 4)  }
//
//        if 13...16 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x - 0.8  , y: pos.y       , z: pos.z + 5)  }
//
//
//        if ( Int(self.name.split(separator: "_")[0])! == 1) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.08, z: pos.z + 0.1)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.10, y: pos.y - 0.08, z: pos.z + 0.1)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.10, y: pos.y + 0.00, z: pos.z + 0.1)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y + 0.00, z: pos.z + 0.1)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 2) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x - 0.20, y: pos.y - 0.08, z: pos.z + 0.1)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.15, y: pos.y - 0.08, z: pos.z + 0.1)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.15, y: pos.y + 0.00, z: pos.z + 0.1)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x - 0.20, y: pos.y + 0.00, z: pos.z + 0.1)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 3) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.10, z: pos.z + 0.02)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.10, z: pos.z + 0.00)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y + 0.00, z: pos.z + 0.00)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y + 0.00, z: pos.z + 0.02)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 5) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.00, z: pos.z + 0.00)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.00, z: pos.z + 0.05)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.05, z: pos.z + 0.05)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.05, z: pos.z + 0.00)}
//
//        }
//
//        pos = node.position
//
//        if ( Int(self.name.split(separator: "_")[0])! == 13) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.00, z: pos.z - 0.05)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y - 0.00, z: pos.z - 0.00)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y + 0.00, z: pos.z - 0.00)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y + 0.00, z: pos.z - 0.05)}
//
//        }
//
//
//        if ( Int(self.name.split(separator: "_")[0])! == 14) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.00, z: pos.z + 0.00)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.10, y: pos.y - 0.00, z: pos.z - 0.13)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.10, y: pos.y - 0.20, z: pos.z - 0.13)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.20, z: pos.z + 0.00)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 15) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.03, z: pos.z + 0.00)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y - 0.03, z: pos.z + 0.00)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y - 0.10, z: pos.z + 0.00)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.10, z: pos.z + 0.00)}
//
//                }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 16) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.10, z: pos.z + 0.00)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y - 0.10, z: pos.z + 0.00)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y - 0.02, z: pos.z + 0.00)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.00, y: pos.y - 0.02, z: pos.z + 0.00)}
//
//                }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 12) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y - 0.00, z: pos.z + 0.10)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y - 0.00, z: pos.z + 0.00)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.00, y: pos.y + 0.00, z: pos.z + 0.00)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x - 0.05, y: pos.y + 0.00, z: pos.z + 0.10)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 8) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.15, y: pos.y - 0.00, z: pos.z + 0.00)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x + 0.20, y: pos.y - 0.00, z: pos.z - 0.03)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x + 0.20, y: pos.y + 0.00, z: pos.z - 0.03)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.15, y: pos.y + 0.00, z: pos.z + 0.00)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 9) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.35, y: pos.y - 0.05, z: pos.z - 0.10)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x + 0.45, y: pos.y - 0.05, z: pos.z - 0.10)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x + 0.45, y: pos.y + 0.00, z: pos.z - 0.10)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.35, y: pos.y + 0.00, z: pos.z - 0.10)}
//
//        }
//
//        if ( Int(self.name.split(separator: "_")[0])! == 10) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x + 0.30, y: pos.y - 0.00, z: pos.z + 0.20)}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x + 0.30, y: pos.y - 0.00, z: pos.z + 0.25)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x + 0.30, y: pos.y + 0.00, z: pos.z + 0.25)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x + 0.30, y: pos.y + 0.00, z: pos.z + 0.20)}
//
//        }
        
//        //FOR 3rd EEEV
//        var pos = node.position
//
//
//        // Validation
//
//        if ( Int(self.name.split(separator: "_")[0])! == 13) {
//
//            if (self.name.contains("pt1")) { node.position = SCNVector3(x: pos.x       - 0.45, y: pos.y - 0.2, z: pos.z - 0.5 )}
//            if (self.name.contains("pt2")) { node.position = SCNVector3(x: pos.x - 0.3 - 0.25, y: pos.y - 0.2, z: pos.z - 0.55)}
//            if (self.name.contains("pt3")) { node.position = SCNVector3(x: pos.x - 0.3 - 0.35, y: pos.y + 0.1, z: pos.z - 0.58)}
//            if (self.name.contains("pt4")) { node.position = SCNVector3(x: pos.x       - 0.45, y: pos.y + 0.0, z: pos.z - 0.5 )}
//
            
//            node.position = SCNVector3(x: pos.x + 10, y: pos.y, z: pos.z)
//            print("DEBUG nodes 12 only : \(node.name)" )
//        }
        
        
//        if ( Int(self.name.split(separator: "_")[0])! == 12) { node.position = SCNVector3(x: pos.x + 10, y: pos.y, z: pos.z)}
//        if 14...17 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x , y: pos.y, z: pos.z + 5) }
        
        
        //3D view
//        if ( Int(self.name.split(separator: "_")[0])! == 12) { node.position = SCNVector3(x: pos.x + 0.4, y: pos.y, z: pos.z) }
//
//        if 3...9 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x - 1.1 , y: pos.y, z: pos.z) }
//
////        if 3...9 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x - 0.3, y: pos.y, z: pos.z) }
//
//        if 14...17 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x , y: pos.y, z: pos.z - 0.1) }
//
//        if 10...11 ~= Int(self.name.split(separator: "_")[0])! { node.position = SCNVector3(x: pos.x + 1.3, y: pos.y, z: pos.z - 1.0) }
//
//
        
        //FOR 1st EEEV
//        var pos = node.position
//        
//        if self.name.split(separator: "_")[0] == "1" { node.position = SCNVector3(x: pos.x - 0.1, y: pos.y + 0.3, z: pos.z) }
//        if self.name.split(separator: "_")[0] == "2" { node.position = SCNVector3(x: pos.x - 0.2, y: pos.y + 0.3, z: pos.z) }
//
//        if self.name.split(separator: "_")[0] == "3" { node.position = SCNVector3(x: pos.x + 1.1, y: pos.y, z: pos.z + 1.0) }
//        if self.name.split(separator: "_")[0] == "5" { node.position = SCNVector3(x: pos.x + 1.1, y: pos.y, z: pos.z + 0.4) }
//        if self.name.split(separator: "_")[0] == "6" { node.position = SCNVector3(x: pos.x + 1.1, y: pos.y, z: pos.z + 0.4) }
//
//        if self.name.split(separator: "_")[0] == "8" { node.position = SCNVector3(x: pos.x + 1.4, y: pos.y, z: pos.z + 0.5) }
//        if self.name.split(separator: "_")[0] == "9" { node.position = SCNVector3(x: pos.x + 1.4, y: pos.y, z: pos.z + 0.5) }
//
//
//        if self.name.split(separator: "_")[0] == "4" { node.position = SCNVector3(x: pos.x , y: pos.y - 10, z: pos.z) }
//        if self.name.split(separator: "_")[0] == "7" { node.position = SCNVector3(x: pos.x , y: pos.y - 10, z: pos.z) }
//
//        if self.name.split(separator: "_")[0] == "14" { node.position = SCNVector3(x: pos.x , y: pos.y , z: pos.z - 10) }
//        if self.name.split(separator: "_")[0] == "15" { node.position = SCNVector3(x: pos.x , y: pos.y , z: pos.z - 10) }
//
//        if ( Int(self.name.split(separator: "_")[0])! >= 17 ) { node.position = SCNVector3(x: pos.x - 0.1 , y: pos.y, z: pos.z) }
//
//        if ( Int(self.name.split(separator: "_")[0])! ==  13) { node.position = SCNVector3(x: pos.x, y: pos.y - 10, z: pos.z) }
//
//        if ( Int(self.name.split(separator: "_")[0])! ==  19) { node.position = SCNVector3(x: pos.x, y: pos.y - 10, z: pos.z) }
//        if ( Int(self.name.split(separator: "_")[0])! ==  20) { node.position = SCNVector3(x: pos.x, y: pos.y - 10, z: pos.z) }
//        if ( Int(self.name.split(separator: "_")[0])! ==  23) { node.position = SCNVector3(x: pos.x, y: pos.y - 10, z: pos.z) }
//        if ( Int(self.name.split(separator: "_")[0])! ==  25) { node.position = SCNVector3(x: pos.x, y: pos.y - 10, z: pos.z) }
//        if ( Int(self.name.split(separator: "_")[0])! ==  19) { node.position = SCNVector3(x: pos.x - 0.1 , y: pos.y, z: pos.z) }

        
        return node
    }
}

fileprivate struct PropertyKeys {
    static let name = "name"
    static let identifier = "identifier"
    static let transform = "transform"
    static let cap_img = "cap_img"
}
