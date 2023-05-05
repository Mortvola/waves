//
//  Settings.swift
//  Waves
//
//  Created by Richard Shields on 5/3/23.
//

import Foundation

class Settings: ObservableObject {
    static var shared = Settings()
    
    @Published var wireframe = true
    @Published var windspeed: Float = 5.0
    @Published var windDirection: Float = 0.0
    @Published var L: Int32 = 16
    var A: Float = 1.0
    var l: Float = 0.25
    
    var step = true
    
    @Published var time: Float = 0
}
