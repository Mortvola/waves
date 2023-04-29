//
//  RenderViewController.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import Foundation
import UIKit
import MetalKit

class RenderViewController: UIViewController {
    var renderer: RenderDelegate!
    
    var prevPoint: CGPoint?
    
    var forward = 0
    var backward = 0
    var left = 0
    var right = 0
    var up = 0
    var down = 0
    
    override func loadView() {
        let mtkView = MTKView()
        self.view = mtkView
        
        MetalView.shared.view = mtkView
        mtkView.device = MetalView.shared.device
        
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.sampleCount = 1
        
        self.renderer = RenderDelegate()
        
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        mtkView.backgroundColor = UIColor.black
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        
        mtkView.delegate = renderer
    }
    
    override func viewDidLoad() {
//        let swipeGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
//        swipeGestureRecognizer.allowedScrollTypesMask = .continuous
//        self.view.addGestureRecognizer(swipeGestureRecognizer);
//
//        // Add a gesture recognizer that triggers when the user touches.
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(select(_:)))
//        self.view.addGestureRecognizer(tapGesture)
    }
}
