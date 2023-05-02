//
//  Vec4.swift
//  Terrain
//
//  Created by Richard Shields on 3/6/23.
//

import Foundation

typealias Vec4 = simd_float4

extension Vec4 {
    func add(_ v: Vec4) -> Vec4 {
        Vec4(self.x + v.x, self.y + v.y, self.z + v.z, self.w + v.w)
    }
    
    func add(_ v: Float) -> Vec4 {
        Vec4(self.x + v, self.y + v, self.z + v, self.w + v)
    }

    func multiply(_ v: Vec4) -> Vec4 {
        Vec4(self.x * v.x, self.y * v.y, self.z * v.z, self.w * v.w)
    }
    
    func multiply(_ v: Float) -> Vec4 {
        Vec4(self.x * v, self.y * v, self.z * v, self.w * v)
    }
    
    func vec3() -> Vec3 {
        Vec3(self.x, self.y, self.z)
    }
}
