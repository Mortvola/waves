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
}
