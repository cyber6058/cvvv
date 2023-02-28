//
//  simd+simd.swift
//  CavernSeer
//
//  Created by Samuel Grush on 12/19/21.
//  Copyright © 2021 Samuel K. Grush. All rights reserved.
//

import Foundation
import ARKit

extension simd_float4x4 {
    func toPosition() -> simd_float3 {
        let col = self.columns.3
        return .init(
            col.x,
            col.y,
            col.z
        )
    }
    
    func toRoundPosition() -> String {
        let col = self.columns.3
        
        let x = String(format: "%.1f", col.x)
        let y = String(format: "%.1f", col.y)
        let z = String(format: "%.1f", col.z)
        
        return("x: \(x), y: \(y), z: \(z)")
    }
}
