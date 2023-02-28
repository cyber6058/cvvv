//
//  SurveyLine.swift
//  CavernSeer
//
//  Created by Samuel Grush on 7/4/20.
//  Copyright © 2021 Samuel K. Grush. All rights reserved.
//

import Foundation
import ARKit /// SCN*, simd_float3, UIColor

final class SurveyLine: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let startIdentifier: SurveyStation.Identifier
    let endIdentifier: SurveyStation.Identifier
    
    let name: String

    var identifier: String { get { "\(startIdentifier.uuidString)_\(endIdentifier.uuidString)" } }

    init(entity: SurveyLineEntity, name: String) {
        guard
            let startId = entity.start.anchor?.anchorIdentifier,
            let endId = entity.end.anchor?.anchorIdentifier
        else {
            fatalError("SurveyLine's start/end has no anchor")
        }
        
        print("DEBUG Line naming 3.1: SurveyLine init(entity: SurveyLineEntity, name: String) name:\(name)")
        self.name = name
        print("DEBUG Line naming 3.2: SurveyLine init(entity: SurveyLineEntity, name: String) self.name:\(self.name)")
        

        self.startIdentifier = startId
        self.endIdentifier = endId
    }

    required init?(coder decoder: NSCoder) {
        
        print("DEBUG SurveyLine required init?(coder decoder: NSCoder)")
        
        self.startIdentifier = decoder.decodeObject(
            of: NSUUID.self,
            forKey: PropertyKeys.startId)! as SurveyStation.Identifier
        self.endIdentifier = decoder.decodeObject(
            of: NSUUID.self,
            forKey: PropertyKeys.endId)! as SurveyStation.Identifier
        
        if decoder.containsValue(forKey: PropertyKeys.name) {
            self.name = decoder.decodeObject(
                of: NSString.self,
                forKey: PropertyKeys.name
            )! as String
        } else {
            self.name = "Line"
        }
        
    }

    func encode(with coder: NSCoder) {
        coder.encode(startIdentifier as NSUUID, forKey: PropertyKeys.startId)
        coder.encode(endIdentifier as NSUUID, forKey: PropertyKeys.endId)
        coder.encode(name as NSString, forKey: PropertyKeys.name)
    }
}


extension SurveyLine {
    func getDistance(
        stationDict: [SurveyStation.Identifier: simd_float3],
        lengthPref: LengthPreference
    ) -> String {
        guard
            let start = stationDict[self.startIdentifier],
            let end = stationDict[self.endIdentifier]
        else {
            fatalError("SurveyLine.toSCNNode start/end not in dict")
        }

        return getDescriptionString(
            start,
            end,
            lengthPref: lengthPref
        )
    }
    
    func toSCNNode_thick(
        stationDict: [SurveyStation.Identifier:SCNNode],
        lengthPref: LengthPreference
    ) -> SCNNode {
        
        guard
            let start = stationDict[self.startIdentifier],
            let end = stationDict[self.endIdentifier]
        else {
            fatalError("SurveyLine.toSCNNode start/end not in dict")
        }

        let startPos = start.simdPosition
        let endPos = end.simdPosition

        let lineNode = drawLine_thick(startPos, endPos, name: self.name)
        
        lineNode.name = self.name

//        let textWrapperNode = drawText(startPos, endPos, lengthPref)
//
//        lineNode.addChildNode(textWrapperNode)

        return lineNode

    }

    func toSCNNode(
        stationDict: [SurveyStation.Identifier:SCNNode],
        lengthPref: LengthPreference
    ) -> SCNNode {
        guard
            let start = stationDict[self.startIdentifier],
            let end = stationDict[self.endIdentifier]
        else {
            fatalError("SurveyLine.toSCNNode start/end not in dict")
        }

        let startPos = start.simdPosition
        let endPos = end.simdPosition

        let lineNode = drawLine(startPos, endPos)
        
        lineNode.name = self.name

        let textWrapperNode = drawText(startPos, endPos, lengthPref)
        
        lineNode.addChildNode(textWrapperNode)
        
        textWrapperNode.name = self.name
        
        let material = SCNMaterial()
        
        if self.name.contains("oncrete")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 1, alpha: 1)}
        if self.name.contains("rebar")  {material.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 1)}
        if self.name.contains("bubble")         {material.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 1)}
        if self.name.contains("aint")    {material.diffuse.contents = UIColor(red: 1, green: 1, blue: 0, alpha: 1)}
        if self.name.contains("peeling")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 1)}
        
        
        return textWrapperNode
//        return lineNode
    }
    
    private func drawLine_thick(
        _ startPos: simd_float3,
        _ endPos: simd_float3,
        name: String
    ) -> SCNNode {
        
        let to = SCNVector3(x: startPos.x, y: startPos.y, z: startPos.z)
        let from = SCNVector3(x: endPos.x, y: endPos.y, z: endPos.z)
        
//        let vector = to - from
        
        let vector = SCNVector3(x: to.x - from.x, y: to.y - from.y, z: to.z - from.z)
        
        let length = sqrtf(vector.x*vector.x + vector.y*vector.y + vector.z*vector.z)
        
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(.black)//UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        

        let cylinder = SCNCylinder(radius: 0.02, height: CGFloat(length))
        cylinder.radialSegmentCount = 6
        cylinder.firstMaterial = material

        let node = SCNNode(geometry: cylinder)

        
        node.position = SCNVector3(x: (to.x + from.x)/2,
                                   y: (to.y + from.y)/2,
                                   z: (to.z + from.z)/2)
        node.eulerAngles = SCNVector3Make(Float(CGFloat(Double.pi/2)), acos((to.z-from.z)/length), atan2((to.y-from.y), (to.x-from.x) ))
        
        
        if self.name.contains("oncrete")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 1, alpha: 0.6)}
        if self.name.contains("rebar")  {material.diffuse.contents = UIColor(red: 1, green: 0, blue: 0, alpha: 0.6)}
        if self.name.contains("bubble")         {material.diffuse.contents = UIColor(red: 0, green: 0, blue: 1, alpha: 0.6)}
        if self.name.contains("aint")    {material.diffuse.contents = UIColor(red: 1, green: 1, blue: 0, alpha: 0.6)}
        if self.name.contains("peeling")  {material.diffuse.contents = UIColor(red: 0, green: 1, blue: 0, alpha: 0.6)}
        
        
        return node
        
    }

    private func drawLine(
        _ startPos: simd_float3,
        _ endPos: simd_float3
    ) -> SCNNode {
        
        let vertices = [startPos, endPos]

        let data = NSData(
            bytes: vertices,
            length: MemoryLayout<simd_float3>.size * 2
        ) as Data

        let vertexSource = SCNGeometrySource(
            data: data,
            semantic: .vertex,
            vectorCount: 2,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<simd_float3>.stride
        )

        let indices: [Int32] = [0, 1]
        let indexData = NSData(
            bytes: indices,
            length: MemoryLayout<Int32>.size * 2
        ) as Data


        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .line,
            primitiveCount: 2,
            bytesPerIndex: MemoryLayout<Int32>.size
        )


        let geo = SCNGeometry(sources: [vertexSource], elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor(.black)//UIColor(red: 1, green: 1, blue: 1, alpha: 1)

        geo.materials = [material]

//        print("#DEBUG SurveyLine to SCNNode: Orange")

        return SCNNode(geometry: geo)
        
        
    }

    private func drawText(
        _ startPos: simd_float3,
        _ endPos: simd_float3,
        _ lengthPref: LengthPreference
    ) -> SCNNode {
        let constraints = SCNBillboardConstraint()
        constraints.freeAxes = .all

        let Description = self.getDescriptionString(
            startPos,
            endPos,
            lengthPref: lengthPref
        )

        let textGeo = SCNText(string: Description, extrusionDepth: 5)
        textGeo.flatness = 0
        textGeo.alignmentMode = CATextLayerAlignmentMode.center.rawValue

        let textMat = SCNMaterial()
        textMat.diffuse.contents = UIColor.blue
        textMat.isDoubleSided = true
        textGeo.materials = [textMat]
        textGeo.font = UIFont(name: "System", size: 2)
        

        let max = textGeo.boundingBox.max
        let min = textGeo.boundingBox.min

        let tx = (max.x - min.x) / 2.0
        let ty = min.y
        let tz = Float(1 / 2.0)

        let textNode = SCNNode(geometry: textGeo)
        textNode.scale = SCNVector3(0.005, 0.005, 0.005)
//        textNode.scale = SCNVector3(0.01, 0.01, 0.01)
        textNode.pivot = SCNMatrix4MakeTranslation(tx, ty, tz)

        let textWrapperNode = SCNNode()
        textWrapperNode.addChildNode(textNode)
        textWrapperNode.constraints = [constraints]
        textWrapperNode.position = SCNVector3(
            x: ((startPos.x + endPos.x) / 2.0),
            y: (startPos.y + endPos.y) / 2.0 + 0.03,
            z: (startPos.z + endPos.z) / 2.0
        )
        textWrapperNode.renderingOrder = 1 

        return textWrapperNode
    }

    private func getDescriptionString(
        _ startPos: simd_float3,
        _ endPos: simd_float3,
        lengthPref: LengthPreference
    ) -> String {
        
        if self.name.contains("center_to_cam") {
            print("DEBUG Line: get distance split list \(self.name.split(separator: "_"))")
            return String(self.name.split(separator: "_")[0] + " " + self.name.split(separator: "_")[1])
        }
        
        let dist = Double(simd_length(startPos - endPos))
        var preferredDistance = lengthPref.fromMetric(dist)
        preferredDistance.value = preferredDistance.value.roundedTo(places: 3)
        
        return preferredDistance.description
    }
}


fileprivate struct PropertyKeys {
    static let startId = "startIdentifier"
    static let endId = "endIdentifier"
    static let name = "name"
}
