//
//  MetalView.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import Foundation
import MetalKit

class MetalView {
    static let shared = MetalView()
    
    let device: MTLDevice
    var view: MTKView?
    
    var width: Float = 0
    var height: Float = 0

    init() {
        let defaultDevice = MTLCreateSystemDefaultDevice()

        self.device = defaultDevice!
    }
}
