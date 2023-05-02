//
//  Math.swift
//  Terrain
//
//  Created by Richard Shields on 2/24/23.
//

import Foundation

typealias Matrix4x4 = matrix_float4x4

extension Matrix4x4 {
    static func identity() -> Matrix4x4 {
        Matrix4x4.init(columns:(Vec4(1, 0, 0, 0),
                                Vec4(0, 1, 0, 0),
                                Vec4(0, 0, 1, 0),
                                Vec4(0, 0, 0, 1)))
    }
    
    static func rotation(radians: Float, axis: SIMD3<Float>) -> Matrix4x4 {
        let unitAxis = normalize(axis)
        let ct = cosf(radians)
        let st = sinf(radians)
        let ci = 1 - ct
        let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
        return Matrix4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                       Vec4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                       Vec4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                       Vec4(                  0,                   0,                   0, 1)))
    }
    
    func rotate(radians: Float, axis: Vec3) -> Matrix4x4 {
        self.multiply(Matrix4x4.rotation(radians: radians, axis: axis))
    }
    
    static func translation(_ x: Float, _ y: Float, _ z: Float) -> Matrix4x4 {
        return Matrix4x4.init(columns:(Vec4(1, 0, 0, 0),
                                       Vec4(0, 1, 0, 0),
                                       Vec4(0, 0, 1, 0),
                                       Vec4(x, y, z, 1)))
    }
    
    func translate(_ x: Float, _ y: Float, _ z: Float) -> Matrix4x4 {
        self.multiply(Matrix4x4.translation(x, y, z))
    }
    
    static func scale(_ x: Float, _ y: Float, _ z: Float) -> Matrix4x4 {
        return Matrix4x4.init(columns:(Vec4(x, 0, 0, 0),
                                       Vec4(0, y, 0, 0),
                                       Vec4(0, 0, z, 0),
                                       Vec4(0, 0, 0, 1)))
    }
    
    func scale (_ x: Float, _ y: Float, _ z: Float) -> Matrix4x4 {
        self.multiply(Matrix4x4.scale(x, y, z))
    }
    
    static func lookAt(offset: Vec3, target: Vec3, up: Vec3) -> Matrix4x4 {
        //    if (
        //      Math.abs(eyex - centerx) < glMatrix.EPSILON &&
        //      Math.abs(eyey - centery) < glMatrix.EPSILON &&
        //      Math.abs(eyez - centerz) < glMatrix.EPSILON
        //    ) {
        //      return identity(out);
        //    }
        let z = target
            .subtract(offset)
            .normalize()
        
        var x = up.cross(z)
        var lengthSquared = x.lengthSquared()
        if (lengthSquared == 0) {
            x = Vec3(0, 0, 0)
        }
        else {
            let inverseLength = 1 / lengthSquared.squareRoot()
            x = x.multiply(inverseLength)
        }
        
        var y = z.cross(x)
        lengthSquared = y.lengthSquared()
        if (lengthSquared == 0) {
            y = Vec3(0, 0, 0)
        }
        else {
            let inverseLength = 1 / lengthSquared.squareRoot()
            y = y.multiply(inverseLength)
        }
        
        let matrix = Matrix4x4.init(columns: (
            vector_float4(x.x, y.x, z.x, 0),
            vector_float4(x.y, y.y, z.y, 0),
            vector_float4(x.z, y.z, z.z, 0),
            vector_float4(
                -(x.x * offset.x + x.y * offset.y + x.z * offset.z),
                -(y.x * offset.x + y.y * offset.y + y.z * offset.z),
                -(z.x * offset.x + z.y * offset.y + z.z * offset.z),
                1
            )
        ))

        return matrix;
    }
    
    func multiply(_ other: Matrix4x4) -> Matrix4x4 {
        matrix_multiply(self, other)
    }
    
    func multiply(_ other: Vec4) -> Vec4 {
        matrix_multiply(self, other)
    }
    
    static func perspectiveLeftHand(fovyRadians fovy: Float, aspect: Float, nearZ: Float, farZ: Float) -> Matrix4x4 {
        let ys = 1 / tanf(fovy * 0.5);
        let xs = ys * aspect;
        let zs = farZ / (farZ - nearZ);
        return Matrix4x4(columns: (
            vector_float4(xs, 0, 0, 0),
            vector_float4(0, ys, 0, 0),
            vector_float4(0, 0, zs, 1),
            vector_float4(0, 0, -nearZ * zs, 0)
        ))
    }
    
    static func orthographic(left: Float, right: Float, top: Float, bottom: Float, near: Float, far: Float) -> Matrix4x4 {
        let width = right - left
        let height = top - bottom
        // We divide 2 (the width and height of the NDC cube: -1 to 1 in x and y) by
        // the width or height to scale the x or y coordinate into the -1 to 1 range (after we apply the offset
        // computed below).
        let xScale = 2 / width
        let yScale = 2 / height
        let zScale = 1 / (far - near)

        // Adding right and left (or top and bottom) and dividing by 2 gives us the center
        // between the sides of the frustum which is also how far off we are from the NDC origin.
        // We need to also scale this offset so that we are moving it into NDC units.
        let xOffset = (right + left) * 0.5 * xScale
        let yOffset = (top + bottom) * 0.5 * yScale
        let zOffset = near * zScale
        
        return Matrix4x4(columns: (
            vector_float4(xScale, 0, 0, 0),
            vector_float4(0, yScale, 0, 0),
            vector_float4(0, 0, zScale, 0),
            vector_float4(-xOffset, -yOffset, -zOffset, 1)
        ))
    }
}

func degreesToRadians(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func degreesToRadians(_ degrees: Double) -> Double {
    return (degrees / 180) * .pi
}
