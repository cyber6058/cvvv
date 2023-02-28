//
//  ModelEntity_extension.swift
//  CavernSeer
//
//  Created by Ho Tin Hung on 2022/11/6.
//  Copyright © 2022 Samuel K. Grush. All rights reserved.
//

import Foundation
import RealityKit

extension ModelEntity{
    func lineTo(_ other: ModelEntity, linked_bbox_loc: String) -> SurveyLineEntity {
        print("DEBUG Line naming 1: survey station lineTO() linked_bbox_loc: \(linked_bbox_loc)")
        return SurveyLineEntity(start: self, end: other, linked_bbox_loc: linked_bbox_loc)
    }
}
