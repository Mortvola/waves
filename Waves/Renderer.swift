//
//  Renderer.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import Foundation
import MetalKit
import GameKit

let maxBuffersInFlight = 3

class Renderer {
    static var shared = Renderer()
    
    private var commandQueue: MTLCommandQueue?
    private var tripleBufferIndex = 0

    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    private var pipelineState: MTLRenderPipelineState? = nil
    
    private var sampler: MTLSamplerState? = nil
    
    private var rectangle1: Rectangle? = nil
    private var rectangle2: Rectangle? = nil
    private var rectangle3: Rectangle? = nil

    private var previousFrameTime: Double?
    
    private var h0ktTexture: MTLTexture? = nil
    
    private var updatePipeline: MTLComputePipelineState? = nil

    private var params: MTLBuffer? = nil
    
    private var inputTexture1: InputTexture? = nil
    private var inputTexture2: InputTexture? = nil

    func initialize() throws {
        guard let queue = MetalView.shared.device.makeCommandQueue() else {
            throw Errors.makeCommandQueueFailed
        }
        
        self.commandQueue = queue
        
        self.pipelineState = try makePipeline()
        
        self.sampler = try makeSampler()

        let windDiretion = simd_float2(1, 1)
        
        inputTexture1 = try InputTexture(commandQueue: commandQueue!, windDirection: windDiretion)
        inputTexture2 = try InputTexture(commandQueue: commandQueue!, windDirection: -windDiretion)
        
        self.rectangle1 = Rectangle(texture: inputTexture1!.h0ktexture!, offset: simd_float2(-512, 0))
        self.rectangle2 = Rectangle(texture: inputTexture2!.h0ktexture!, offset: simd_float2(0, 0))
        
        let N = 512
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: N, mipmapped: false);
        textureDescr.usage = [.shaderWrite, .shaderRead]
        
        h0ktTexture = MetalView.shared.device.makeTexture(descriptor: textureDescr)
        
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let function = library?.makeFunction(name: "makeTimeTexture") else {
            return
        }
                
        updatePipeline = try MetalView.shared.device.makeComputePipelineState(function: function)
        
        params = MetalView.shared.device.makeBuffer(length: MemoryLayout<Float>.size)!
        
        self.rectangle3 = Rectangle(texture: h0ktTexture!, offset: simd_float2(-512, -512));
    }
              
    func buildVertexDescriptor() -> MTLVertexDescriptor {
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        // Buffer 1
        mtlVertexDescriptor.attributes[0].format = .float3
        mtlVertexDescriptor.attributes[0].bufferIndex = 0
        mtlVertexDescriptor.attributes[0].offset = 0

        mtlVertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride

        mtlVertexDescriptor.attributes[1].format = .float2
        mtlVertexDescriptor.attributes[1].bufferIndex = 1
        mtlVertexDescriptor.attributes[1].offset = 0

        mtlVertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride

        return mtlVertexDescriptor
    }

    func makePipeline() throws -> MTLRenderPipelineState {
        let vertexDescriptor = buildVertexDescriptor();
        
        let library = MetalView.shared.device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        if vertexFunction == nil || fragmentFunction == nil {
            throw Errors.makeFunctionError
        }

        let descr = MTLRenderPipelineDescriptor()
        descr.label = "Main"
        descr.rasterSampleCount = MetalView.shared.view!.sampleCount
        descr.vertexFunction = vertexFunction
        descr.fragmentFunction = fragmentFunction
        descr.vertexDescriptor = vertexDescriptor
        
        descr.colorAttachments[0].pixelFormat = MetalView.shared.view!.colorPixelFormat
        descr.depthAttachmentPixelFormat = MetalView.shared.view!.depthStencilPixelFormat
        descr.stencilAttachmentPixelFormat = MTLPixelFormat.invalid
                
        return try MetalView.shared.device.makeRenderPipelineState(descriptor: descr)
    }
    
    func makeSampler() throws -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        
        return MetalView.shared.device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    func getTime() -> Double {
        return ProcessInfo.processInfo.systemUptime
    }
    
    func getElapsedTime() -> Double? {
        let now = ProcessInfo.processInfo.systemUptime

        defer {
            previousFrameTime = now
        }
        
        if let previousFrameTime = previousFrameTime {
            let elapsedTime = now - previousFrameTime
            
            return elapsedTime
        }
        
        return nil
    }

    func render(in view: MTKView) throws {
        guard let commandQueue = self.commandQueue else {
            return
        }
        
        guard let pipelineState = self.pipelineState else {
            return
        }
        
        guard let rectangle1 = rectangle1, let rectangle2 = rectangle2, let rectangle3 = rectangle3 else {
            return
        }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        updateTexture(commandQueue: commandQueue);
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "\(self.tripleBufferIndex)"
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    // Render stuff...
                    
                    renderEncoder.setRenderPipelineState(pipelineState)
                    
                    rectangle1.draw(renderEncoder: renderEncoder, sampler: sampler!)
                    rectangle2.draw(renderEncoder: renderEncoder, sampler: sampler!)
                    rectangle3.draw(renderEncoder: renderEncoder, sampler: sampler!)

                    renderEncoder.endEncoding()
                }

                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }

            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            commandBuffer.commit()
        }
    }
    
    func updateTexture(commandQueue: MTLCommandQueue) {
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState(updatePipeline!)
                
                let p = params!.contents().bindMemory(to: Float.self, capacity: MemoryLayout<Float>.size)
                p[0] = Float(getTime())
                
                computeEncoder.setBuffer(params, offset: 0, index: 0)
                computeEncoder.setTexture(inputTexture1?.h0ktexture, index: 0)
                computeEncoder.setTexture(inputTexture2?.h0ktexture, index: 1)
                computeEncoder.setTexture(h0ktTexture, index: 2)
                
                let dimension = 512
                let threadsPerGrid = MTLSizeMake(dimension, dimension, 1)
                
                let width = updatePipeline!.threadExecutionWidth
                let height = updatePipeline!.maxTotalThreadsPerThreadgroup / width
                
                let threadsPerGroup = MTLSizeMake(width, height, 1)
                
                computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                
                computeEncoder.endEncoding()
                
                commandBuffer.commit()
            }
        }
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
