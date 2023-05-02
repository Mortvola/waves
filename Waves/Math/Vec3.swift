//
//  Vec3.swift
//  Terrain
//
//  Created by Richard Shields on 2/26/23.
//

import Foundation

typealias Vec3 = simd_float3

extension Vec3 {
    func rotateX(_ radians: Float) -> Vec3 {
        Vec3 (
            self.x,
            self.y * cos(radians) - self.z * sin(radians),
            self.y * sin(radians) + self.z * cos(radians)
        )
    }
    
    func rotateY(_ radians: Float) -> Vec3 {
        Vec3 (
            self.z * sin(radians) + self.x * cos(radians),
            self.y,
            self.z * cos(radians) - self.x * sin(radians)
        )
    }
    
    func rotateZ(_ radians: Float) -> Vec3 {
        Vec3 (
            self.x * cos(radians) - self.y * sin(radians),
            self.x * sin(radians) + self.y * cos(radians),
            self.z
        )
    }
    
    func multiply(_ v: Vec3) -> Vec3 {
        Vec3(self.x * v.x, self.y * v.y, self.z * v.z)
    }
    
    func multiply(_ v: Float) -> Vec3 {
        Vec3(self.x * v, self.y * v, self.z * v)
    }

    func add(_ v: Vec3) -> Vec3 {
        Vec3(self.x + v.x, self.y + v.y, self.z + v.z)
    }
    
    func add(_ v: Float) -> Vec3 {
        Vec3(self.x + v, self.y + v, self.z + v)
    }
    
    func subtract(_ v: Vec3) -> Vec3 {
        Vec3(self.x - v.x, self.y - v.y, self.z - v.z)
    }
    
    func normalize() -> Vec3 {
        simd_normalize(self)
    }
    
    func length() -> Float {
        lengthSquared().squareRoot()
    }
    
    func lengthSquared() -> Float {
        simd_length_squared(self)
    }
    
    func cross(_ other: Vec3) -> Vec3 {
        simd_cross(self, other)
    }
    
    func vec4() -> Vec4 {
        return Vec4(self.x, self.y, self.z, 1.0)
    }
}

typealias VecUInt3 = vector_uint3
