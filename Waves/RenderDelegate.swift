//
//  RenderDelegate.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import Foundation
import MetalKit

class RenderDelegate: NSObject, MTKViewDelegate {
    var camera: Camera
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MetalView.shared.width = Float(size.width)
        MetalView.shared.height = Float(size.height)

        camera.updateViewDimensions()
    }
    
    init(camera: Camera) {
        self.camera = camera

        super.init()
        
        Task {
            do {
                try Renderer.shared.initialize(camera: camera)
            }
            catch {
                print(error)
                throw error
            }
        }
    }
    
    func draw(in view: MTKView) {
        try? Renderer.shared.render(in: view)
    }
    
    func setPaused(paused: Bool) {
        Renderer.shared.setPaused(paused: paused)
    }
}
