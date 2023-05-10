//
//  RenderViewController.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import Foundation
import UIKit
import MetalKit

extension MTKView {
    open override var canBecomeFocused: Bool {
        return true
    }
    
    open override var canBecomeFirstResponder: Bool {
        return true
    }
}

class RenderViewController: UIViewController {
    var renderer: RenderDelegate!
    
    var prevPoint: CGPoint?
    
    var forward = 0
    var backward = 0
    var left = 0
    var right = 0
    var up = 0
    var down = 0
    
    var camera = Camera()
    
    override func loadView() {
        let mtkView = MTKView()
        self.view = mtkView
        
        MetalView.shared.view = mtkView
        mtkView.device = MetalView.shared.device
        
        mtkView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.sampleCount = 1
        
        self.renderer = RenderDelegate(camera: camera)
        
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        mtkView.backgroundColor = UIColor.black
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        
        mtkView.delegate = renderer
    }
    
    override func viewDidLoad() {
        let swipeGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(_:)))
        swipeGestureRecognizer.allowedScrollTypesMask = .continuous
        self.view.addGestureRecognizer(swipeGestureRecognizer);
        
        // Add a gesture recognizer that triggers when the user touches.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(select(_:)))
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc
    override func select(_ sender: Any?) {
        self.view.becomeFirstResponder()
    }
    
    @objc func didPan(_ sender: UIPanGestureRecognizer) {
        let point = sender.translation(in: self.view)
        
        if sender.state != .began {
            if let prevPoint = self.prevPoint {
                let xDelta = -Float(point.x - prevPoint.x);
                let yDelta = -Float(point.y - prevPoint.y);
                let sensitivity: Float = 0.1;
                
                camera.updateLookAt(yawChange: xDelta * sensitivity, pitchChange: yDelta * sensitivity);
            }
        }
        
        self.prevPoint = point
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touches.forEach { touch in
            let point = touch.preciseLocation(in: view)
            let prevPoint = touch.precisePreviousLocation(in: view)
            
            let xDelta = -Float(point.x - prevPoint.x);
            let yDelta = -Float(point.y - prevPoint.y);
            let sensitivity: Float = 0.1;
            
            camera.updateLookAt(yawChange: xDelta * sensitivity, pitchChange: yDelta * sensitivity);
        }
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var keyPressed = false;
        
        presses.forEach{ press in
            if let key = press.key?.charactersIgnoringModifiers {
                switch (key) {
                case "e":
                    self.forward = 1
                    keyPressed = true
                    break;
                    
                case "d":
                    self.backward = 1
                    keyPressed = true
                    break;
                    
                case "s":
                    self.left = 1
                    keyPressed = true
                    break;
                    
                case "f":
                    self.right = 1
                    keyPressed = true
                    break;
                    
                case "t":
                    self.up = 1
                    keyPressed = true
                    break;
                    
                case "g":
                    self.down = 1
                    keyPressed = true
                    break;
                    
                default:
                    break;
                }
            }
        }
        
        if keyPressed {
            camera.setMoveDirection(
                x: Float(self.right - self.left),
                y: Float(self.up - self.down),
                z: Float(self.forward - self.backward)
            )
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var keyReleased = false;
        
        presses.forEach{ press in
            if let key = press.key?.charactersIgnoringModifiers {
                switch (key) {
                case "e":
                    self.forward = 0
                    keyReleased = true
                    break;
                    
                case "d":
                    self.backward = 0
                    keyReleased = true
                    break;
                    
                case "s":
                    self.left = 0
                    keyReleased = true
                    break;
                    
                case "f":
                    self.right = 0
                    keyReleased = true
                    break;
                    
                case "t":
                    self.up = 0
                    keyReleased = true
                    break;
                    
                case "g":
                    self.down = 0
                    keyReleased = true
                    break;
                    
                default:
                    break;
                }
            }
        }
        
        if keyReleased {
            camera.setMoveDirection(
                x: Float(self.right - self.left),
                y: Float(self.up - self.down),
                z: Float(self.forward - self.backward)
            )
        }
    }
}
