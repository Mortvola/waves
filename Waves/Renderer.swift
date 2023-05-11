//
//  Renderer.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import Foundation
import MetalKit
import GameKit

var clock = Clock();

let maxBuffersInFlight = 3

class Renderer {
    static var shared = Renderer()
    
    private var commandQueue: MTLCommandQueue?
    public var depthState: MTLDepthStencilState?

    private var tripleBufferIndex = 0

    private var N = 256
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    private var pipelineState: MTLRenderPipelineState? = nil
    private var wavePipelineState: MTLRenderPipelineState? = nil
    private var wireframePipelineState: MTLRenderPipelineState? = nil
    private var normalsPipelineState: MTLRenderPipelineState? = nil

    private var sampler: MTLSamplerState? = nil
    
    private var h0ktTexture: FFTTexture?
    private var displacementX: FFTTexture?
    private var displacementZ: FFTTexture?
    private var slopeX: FFTTexture?
    private var slopeZ: FFTTexture?

    private var updatePipeline: MTLComputePipelineState? = nil

    private var frameConstants: MTLBuffer? = nil
    
    private var inputTexture: InputTexture? = nil
    
    private var wave: Mesh? = nil
    private var normals: MTLBuffer? = nil
    
    private var camera: Camera!
    
    private var lastUpdateTime: Float? = nil
    
    private var useNaivePipeline = false
    private var naivePipeline: MTLComputePipelineState? = nil
    
    private var params: MTLBuffer? = nil

    func initialize(camera: Camera) throws {
        do {
            self.camera = camera
            
            // When using the naive pipeline, set the clock to paused
            // because rendering with the naive pipeline is very slow.
            if self.useNaivePipeline {
                clock.pause()
            }
            
            guard let queue = MetalView.shared.device.makeCommandQueue() else {
                throw Errors.makeCommandQueueFailed
            }
            
            self.commandQueue = queue
            
            self.wavePipelineState = try makeWavePipeline()
            self.wireframePipelineState = try makeWireframePipeline()
            self.normalsPipelineState = try makeNormalsPipeline()
            
            self.sampler = try makeSampler()
            
            inputTexture = try InputTexture(commandQueue: commandQueue!, N: N)
            
            let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: N, mipmapped: false);
            textureDescr.usage = [.shaderWrite, .shaderRead]
            
            h0ktTexture = try FFTTexture(N: N, commandQueue: commandQueue!)
            displacementX = try FFTTexture(N: N, commandQueue: commandQueue!)
            displacementZ = try FFTTexture(N: N, commandQueue: commandQueue!)
            slopeX = try FFTTexture(N: N, commandQueue: commandQueue!)
            slopeZ = try FFTTexture(N: N, commandQueue: commandQueue!)

            let library = MetalView.shared.device.makeDefaultLibrary()
            
            guard let function = library?.makeFunction(name: "makeTimeTexture2") else {
                return
            }
            
            updatePipeline = try MetalView.shared.device.makeComputePipelineState(function: function)
            
            wave = try Mesh(N: N)
            
            normals = wave!.getNormalLines()
            
            frameConstants = MetalView.shared.device.makeBuffer(length: MemoryLayout<FrameConstants>.size)!
            
            camera.cameraOffset.y = 40
            camera.cameraOffset.z = -250
            
            camera.updateLookAt(yawChange: 0, pitchChange: 25)
            
            makeNaivePipeline(commandQueue: commandQueue!)
            
            let depthStateDescriptor = MTLDepthStencilDescriptor()
            depthStateDescriptor.depthCompareFunction = .less
            depthStateDescriptor.isDepthWriteEnabled = true
            
            guard let state = MetalView.shared.device.makeDepthStencilState(descriptor:depthStateDescriptor) else {
                throw Errors.makeFunctionError
            }
            
            self.depthState = state
            
            self.params = MetalView.shared.device.makeBuffer(length: MemoryLayout<Params>.size)!
            
        }
        catch{
            print(error)
            throw error
        }
    }

    func makeNaivePipeline(commandQueue: MTLCommandQueue) {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let function = library?.makeFunction(name: "naiveHeightCompute") else {
            return
        }
                
        naivePipeline = try? MetalView.shared.device.makeComputePipelineState(function: function)
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

    func buildNormalsVertexDescriptor() -> MTLVertexDescriptor {
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        // Buffer 1
        mtlVertexDescriptor.attributes[0].format = .float3
        mtlVertexDescriptor.attributes[0].bufferIndex = 0
        mtlVertexDescriptor.attributes[0].offset = 0

        mtlVertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride

        return mtlVertexDescriptor
    }

    func makeWavePipeline() throws -> MTLRenderPipelineState {
        let vertexDescriptor = buildVertexDescriptor();
        
        let library = MetalView.shared.device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexWaveShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentWaterShader")
        
        if vertexFunction == nil || fragmentFunction == nil {
            throw Errors.makeFunctionError
        }

        let descr = MTLRenderPipelineDescriptor()
        descr.label = "Wave"
        descr.rasterSampleCount = MetalView.shared.view!.sampleCount
        descr.vertexFunction = vertexFunction
        descr.fragmentFunction = fragmentFunction
        descr.vertexDescriptor = vertexDescriptor
        
        descr.colorAttachments[0].pixelFormat = MetalView.shared.view!.colorPixelFormat
        descr.depthAttachmentPixelFormat = MetalView.shared.view!.depthStencilPixelFormat
        descr.stencilAttachmentPixelFormat = MTLPixelFormat.invalid
                
        return try MetalView.shared.device.makeRenderPipelineState(descriptor: descr)
    }

    func makeWireframePipeline() throws -> MTLRenderPipelineState {
        let vertexDescriptor = buildVertexDescriptor();
        
        let library = MetalView.shared.device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexWaveShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentWireframeShader")
        
        if vertexFunction == nil || fragmentFunction == nil {
            throw Errors.makeFunctionError
        }

        let descr = MTLRenderPipelineDescriptor()
        descr.label = "Wave"
        descr.rasterSampleCount = MetalView.shared.view!.sampleCount
        descr.vertexFunction = vertexFunction
        descr.fragmentFunction = fragmentFunction
        descr.vertexDescriptor = vertexDescriptor
        
        descr.colorAttachments[0].pixelFormat = MetalView.shared.view!.colorPixelFormat
        descr.depthAttachmentPixelFormat = MetalView.shared.view!.depthStencilPixelFormat
        descr.stencilAttachmentPixelFormat = MTLPixelFormat.invalid
                
        return try MetalView.shared.device.makeRenderPipelineState(descriptor: descr)
    }

    func makeNormalsPipeline() throws -> MTLRenderPipelineState {
        let vertexDescriptor = buildNormalsVertexDescriptor();
        
        let library = MetalView.shared.device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexNormalsShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentNormalsShader")
        
        if vertexFunction == nil || fragmentFunction == nil {
            throw Errors.makeFunctionError
        }

        let descr = MTLRenderPipelineDescriptor()
        descr.label = "Normals"
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

    private func updateState() {
        /// Update any game state before rendering
        
        if let elapsedTime = clock.getElapsedTime() {
            self.camera.updatePostion(elapsedTime: elapsedTime)
        }
    }
    
    func updateTexture(commandQueue: MTLCommandQueue) {
        guard let updatePipeline = updatePipeline else {
            return
        }

        var time = Float(clock.getTime())

        if time != lastUpdateTime {
            if let commandBuffer = commandQueue.makeCommandBuffer() {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    if let naivePipeline = naivePipeline, useNaivePipeline {
                        computeEncoder.setComputePipelineState(naivePipeline)
                        
                        let p1 = self.params!.contents().bindMemory(to: Params.self, capacity: MemoryLayout<Params>.size)
                        p1[0].windDirection = simd_float2(cos(Settings.shared.windDirection / 180 * Float.pi), sin(Settings.shared.windDirection / 180 * Float.pi))
                        p1[0].windSpeed = Settings.shared.windspeed
                        p1[0].windDirectionalFactor = Settings.shared.windDirectionalFactor
                        p1[0].L = Settings.shared.L
                        p1[0].A = Settings.shared.A
                        p1[0].l = Settings.shared.l
                        p1[0].xzDisplacement = Settings.shared.xzDisplacement
                        
                        computeEncoder.setBuffer(self.params, offset: 0, index: 0)
                        
                        var time = Float(clock.getTime())
                        computeEncoder.setBytes(&time, length: MemoryLayout<Float>.size, index: 1)
                        
                        computeEncoder.setTexture(inputTexture?.noiseTexture1, index: 0)
                        computeEncoder.setTexture(inputTexture?.noiseTexture2, index: 1)
                        computeEncoder.setTexture(inputTexture?.noiseTexture3, index: 2)
                        computeEncoder.setTexture(inputTexture?.noiseTexture4, index: 3)
                        
                        computeEncoder.setTexture(h0ktTexture!.texture, index: 4)
                        computeEncoder.setTexture(displacementX!.texture, index: 5)
                        computeEncoder.setTexture(displacementZ!.texture, index: 6)
                        computeEncoder.setTexture(slopeX!.texture, index: 7)
                        computeEncoder.setTexture(slopeZ!.texture, index: 8)
                        
                        let threadsPerGrid = MTLSizeMake(N, N, 1)
                        
                        let width = updatePipeline.threadExecutionWidth
                        let height = updatePipeline.maxTotalThreadsPerThreadgroup / width
                        
                        let threadsPerGroup = MTLSizeMake(width, height, 1)
                        
                        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                    }
                    else {
                        computeEncoder.setComputePipelineState(updatePipeline)
                        
                        let p1 = self.params!.contents().bindMemory(to: Params.self, capacity: MemoryLayout<Params>.size)
                        p1[0].windDirection = simd_float2(cos(Settings.shared.windDirection / 180 * Float.pi), sin(Settings.shared.windDirection / 180 * Float.pi))
                        p1[0].windSpeed = Settings.shared.windspeed
                        p1[0].windDirectionalFactor = Settings.shared.windDirectionalFactor
                        p1[0].L = Settings.shared.L
                        p1[0].A = Settings.shared.A
                        p1[0].l = Settings.shared.l
                        p1[0].xzDisplacement = Settings.shared.xzDisplacement
                        
                        computeEncoder.setBuffer(self.params, offset: 0, index: 0)
                        
                        computeEncoder.setBytes(&time, length: MemoryLayout<Float>.size, index: 1)
                        
                        computeEncoder.setTexture(inputTexture?.noiseTexture1, index: 0)
                        computeEncoder.setTexture(inputTexture?.noiseTexture2, index: 1)
                        computeEncoder.setTexture(inputTexture?.noiseTexture3, index: 2)
                        computeEncoder.setTexture(inputTexture?.noiseTexture4, index: 3)
                        
                        computeEncoder.setTexture(h0ktTexture!.texture, index: 4)
                        computeEncoder.setTexture(displacementX!.texture, index: 5)
                        computeEncoder.setTexture(displacementZ!.texture, index: 6)
                        computeEncoder.setTexture(slopeX!.texture, index: 7)
                        computeEncoder.setTexture(slopeZ!.texture, index: 8)
                        
                        let threadsPerGrid = MTLSizeMake(N, N, 1)
                        
                        let width = updatePipeline.threadExecutionWidth
                        let height = updatePipeline.maxTotalThreadsPerThreadgroup / width
                        
                        let threadsPerGroup = MTLSizeMake(width, height, 1)
                        
                        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                        
                        // Perform the FFT transform
                        h0ktTexture!.transform(computeEncoder: computeEncoder)
                        displacementX!.transform(computeEncoder: computeEncoder)
                        displacementZ!.transform(computeEncoder: computeEncoder)
                        slopeX!.transform(computeEncoder: computeEncoder)
                        slopeZ!.transform(computeEncoder: computeEncoder)
                    }
                    
                    computeEncoder.endEncoding()
                    
                    commandBuffer.commit()
                    
                    lastUpdateTime = time;
                }
            }
        }
    }
    
    func updateFrameConstants() {
        let constants = UnsafeMutableRawPointer(frameConstants!.contents()).bindMemory(to: FrameConstants.self, capacity: 1)

        constants[0].projectionMatrix = camera!.projectionMatrix
        constants[0].viewMatrix = camera!.getViewMatrix()
    }
    
    func render(in view: MTKView) throws {
        guard let commandQueue = self.commandQueue else {
            return
        }
        
        guard
//            let pipelineState = self.pipelineState,
            let wavePipelineState = self.wavePipelineState,
            let wireframePipelineState = self.wireframePipelineState,
            let normalsPipelineState = self.normalsPipelineState,
            let depthState = self.depthState
        else {
            return
        }
        
//        guard let rectangle1 = rectangle1, let rectangle2 = rectangle2, let rectangle3 = rectangle3 else {
//            return
//        }
//
//        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        updateTexture(commandQueue: commandQueue)
        
        updateState()
        
        if frameConstants == nil {
            return
        }
        
        updateFrameConstants()
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "\(self.tripleBufferIndex)"
            
//            if !tested {
//                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
//                    test?.run(computeEncoder: computeEncoder)
//
//                    computeEncoder.endEncoding()
//
////                    tested = true
//                }
//            }
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    // Render stuff...
                    
                    renderEncoder.setRenderPipelineState(wavePipelineState)
                    
                    renderEncoder.setCullMode(.back)
                    renderEncoder.setDepthStencilState(depthState)

                    renderEncoder.setVertexBuffer(frameConstants, offset: 0, index: BufferIndex.frameConstants.rawValue)
                    
                    renderEncoder.setVertexTexture(h0ktTexture!.texture, index: 3)
                    renderEncoder.setVertexTexture(displacementX!.texture, index: 4)
                    renderEncoder.setVertexTexture(displacementZ!.texture, index: 5)
                    renderEncoder.setVertexTexture(slopeX!.texture, index: 6)
                    renderEncoder.setVertexTexture(slopeZ!.texture, index: 7)

//                    var color = simd_float4(6.0 / 255.0, 66.0 / 255.0, 115.0 / 255.0, 1)
                    var color = simd_float4(0.18, 0.38, 0.42, 1)
                    renderEncoder.setFragmentBytes(&color, length: MemoryLayout<simd_float4>.size, index: 0)

                    wave!.draw(renderEncoder: renderEncoder)

                    if Settings.shared.wireframe {
                        renderEncoder.setRenderPipelineState(wireframePipelineState)

                        renderEncoder.setTriangleFillMode(.lines)
                        
                        color = simd_float4(1, 0, 0, 1)
                        
                        renderEncoder.setFragmentBytes(&color, length: MemoryLayout<simd_float4>.size, index: 0)

                        wave!.draw(renderEncoder: renderEncoder)
                    }
                    
                    if Settings.shared.normals {
                        renderEncoder.setRenderPipelineState(normalsPipelineState)
                        
                        renderEncoder.setVertexBuffer(normals, offset: 0, index: 0)
                        
                        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: normals!.length / MemoryLayout<simd_float3>.size)
                    }
                    
                    renderEncoder.endEncoding()
                }

                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }

//            let semaphore = inFlightSemaphore
//            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
//                semaphore.signal()
//            }
            
            commandBuffer.commit()
        }
    }
}
