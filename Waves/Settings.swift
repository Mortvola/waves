//
//  Settings.swift
//  Waves
//
//  Created by Richard Shields on 5/3/23.
//

import Foundation

class Settings: ObservableObject {
    static var shared = Settings()
    
    @Published var wireframe = false
    @Published var normals = false
    @Published var xzDisplacement = true
    @Published var windspeed: Float = 5
    @Published var windDirection: Float = 0.0
    @Published var windDirectionalFactor: Float = 6.0
    @Published var L: Int32 = 256
    var A: Float = 0.0005
    var l: Float = 0.1
}
