//
//  Vec2.swift
//  Terrain
//
//  Created by Richard Shields on 2/28/23.
//

import Foundation

typealias Vec2 = simd_float2

extension Vec2 {
    func subtract(_ v: Vec2) -> Vec2 {
        Vec2(self.x - v.x, self.y - v.y)
    }
}

typealias VecUInt2 = vector_uint2
