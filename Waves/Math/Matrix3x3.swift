//
//  Matrix3x3.swift
//  Terrain4
//
//  Created by Richard Shields on 3/21/23.
//

import Foundation

typealias Matrix3x3 = matrix_float3x3

extension Matrix3x3 {
    static func identity() -> Matrix3x3 {
        Matrix3x3.init(columns:(Vec3(1, 0, 0),
                                Vec3(0, 1, 0),
                                Vec3(0, 0, 1)))
    }
}
