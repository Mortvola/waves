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

    private var N = 256
    
    private let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)

    private var pipelineState: MTLRenderPipelineState? = nil
    private var wavePipelineState: MTLRenderPipelineState? = nil
    
    private var sampler: MTLSamplerState? = nil
    
    private var rectangle1: Rectangle? = nil
    private var rectangle2: Rectangle? = nil
    private var rectangle3: Rectangle? = nil

    private var previousFrameTime: Double?
    
    private var h0ktTexture: [MTLTexture] = []
    private var pingpong = 0

    private var testTexture: [MTLTexture] = []

    private var updatePipeline: MTLComputePipelineState? = nil

    private var params: MTLBuffer? = nil
    private var frameConstants: MTLBuffer? = nil
    
    private var inputTexture: InputTexture? = nil
    
    private var butterflyTexture: MTLTexture? = nil
    private var inverseHorzFFTPipeline: MTLComputePipelineState? = nil
    private var inverseVertFFTPipeline: MTLComputePipelineState? = nil
    private var inverseFFTDividePipeline: MTLComputePipelineState? = nil
    
    private var wave: MTKMesh? = nil
    
    private var camera: Camera = Camera()
    
    private var test: TestFFT? = nil
    private var tested = false
    
    func initialize() throws {
        do {
            guard let queue = MetalView.shared.device.makeCommandQueue() else {
                throw Errors.makeCommandQueueFailed
            }
            
            self.commandQueue = queue
            
//            self.pipelineState = try makePipeline()
            self.wavePipelineState = try makeWavePipeline()
            
            self.sampler = try makeSampler()
            
            let windDiretion = simd_float2(0, 1)
            let windSpeed: Float = 10; // 3.75;
            
            inputTexture = try InputTexture(commandQueue: commandQueue!, N: N, windDirection: windDiretion, windSpeed: windSpeed)
            
            self.rectangle1 = Rectangle(texture: inputTexture!.h0ktexture!, size: Float(N), offset: simd_float2(-Float(N), 0))
            self.rectangle2 = Rectangle(texture: inputTexture!.h0ktexture!, size: Float(N), offset: simd_float2(0, 0))
            
            let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: N, mipmapped: false);
            textureDescr.usage = [.shaderWrite, .shaderRead]
            
            h0ktTexture.append(MetalView.shared.device.makeTexture(descriptor: textureDescr)!)
            h0ktTexture.append(MetalView.shared.device.makeTexture(descriptor: textureDescr)!)

            let library = MetalView.shared.device.makeDefaultLibrary()
            
            guard let function = library?.makeFunction(name: "makeTimeTexture") else {
                return
            }
            
            updatePipeline = try MetalView.shared.device.makeComputePipelineState(function: function)
            
            params = MetalView.shared.device.makeBuffer(length: MemoryLayout<Float>.size)!
            
            self.rectangle3 = Rectangle(texture: h0ktTexture[0], size: Float(N), offset: simd_float2(-Float(N), -Float(N)));
            
            self.butterflyTexture = try makeButterflyTexture(N: N, inverse: true, commandQueue: commandQueue!)
            
            makeInverseFFTPipelines()
            
            wave = try allocatePlane(dimensions: simd_float2(Float(N * 2), Float(N * 2)), segments: simd_uint2(UInt32(N - 1), UInt32(N - 1)))
            
            frameConstants = MetalView.shared.device.makeBuffer(length: MemoryLayout<FrameConstants>.size)!
            
            camera.cameraOffset.y = 40
            camera.cameraOffset.z = -250
            
            camera.updateLookAt(yawChange: 0, pitchChange: 25)
            
            test = try TestFFT(N: 8, commandQueue: commandQueue!)
        }
        catch{
            print(error)
            throw error
        }
    }

    func makeInverseFFTPipelines() {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let horzFunction = library?.makeFunction(name: "inverseHorzFFTStage") else {
            return
        }
        
        guard let vertFunction = library?.makeFunction(name: "inverseVertFFTStage") else {
            return
        }

        inverseHorzFFTPipeline = try? MetalView.shared.device.makeComputePipelineState(function: horzFunction)
        
        inverseVertFFTPipeline = try? MetalView.shared.device.makeComputePipelineState(function: vertFunction)
        
        guard let inverseFFTDivide = library?.makeFunction(name: "inverseFFTDivide") else {
            return
        }
        
        inverseFFTDividePipeline = try? MetalView.shared.device.makeComputePipelineState(function: inverseFFTDivide)
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
    
    func updateTexture(commandQueue: MTLCommandQueue) {
        guard
            let inverseHorzFFTPipeline = inverseHorzFFTPipeline,
            let inverseVertFFTPipeline = inverseVertFFTPipeline
        else {
            return
        }

        if inverseFFTDividePipeline == nil {
            return
        }

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
//                test?.run(computeEncoder: computeEncoder)

                computeEncoder.setComputePipelineState(updatePipeline!)
                
                let p = params!.contents().bindMemory(to: Float.self, capacity: MemoryLayout<Float>.size)
                p[0] = Float(getTime())
                
                computeEncoder.setBuffer(params, offset: 0, index: 0)
                computeEncoder.setTexture(inputTexture?.h0ktexture, index: 0)
                computeEncoder.setTexture(h0ktTexture[0], index: 1)
                
                let threadsPerGrid = MTLSizeMake(N, N, 1)
                
                let width = updatePipeline!.threadExecutionWidth
                let height = updatePipeline!.maxTotalThreadsPerThreadgroup / width
                
                let threadsPerGroup = MTLSizeMake(width, height, 1)
                
                computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                
                // Perform horizontal inverse FFT
                computeEncoder.setComputePipelineState(inverseHorzFFTPipeline)

                computeEncoder.setTexture(butterflyTexture, index: 2)

                let stages = Int(log2(Float(N)))
                                
                for stage in 0..<stages {
                    computeEncoder.setTexture(h0ktTexture[pingpong], index: 0)
                    computeEncoder.setTexture(h0ktTexture[pingpong ^ 1], index: 1)

                    var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))

                    computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
                    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                    
                    pingpong ^= 1
                }

                inverseFFTDivide(computeEncoder: computeEncoder)

                // Perform horizontal inverse FFT
                computeEncoder.setComputePipelineState(inverseVertFFTPipeline)

                computeEncoder.setTexture(butterflyTexture, index: 2)

                for stage in 0..<stages {
                    computeEncoder.setTexture(h0ktTexture[pingpong], index: 0)
                    computeEncoder.setTexture(h0ktTexture[pingpong ^ 1], index: 1)

                    var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))

                    computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
                    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                    
                    pingpong ^= 1
                }

                inverseFFTDivide(computeEncoder: computeEncoder)
                
                computeEncoder.endEncoding()
                
                commandBuffer.commit()
            }
        }
    }
    
    func inverseFFTDivide(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(inverseFFTDividePipeline!)

        let threadsPerGrid = MTLSizeMake(N, N, 1)
        
        let width = inverseFFTDividePipeline!.threadExecutionWidth
        let height = inverseFFTDividePipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var multiplier = 1.0 / Float(N)

        computeEncoder.setBytes(&multiplier, length: MemoryLayout<Float>.size, index: 0)
        computeEncoder.setTexture(h0ktTexture[pingpong], index: 0)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
    }

    func updateFrameConstants() {
        let constants = UnsafeMutableRawPointer(frameConstants!.contents()).bindMemory(to: FrameConstants.self, capacity: 1)

        constants[0].projectionMatrix = camera.projectionMatrix
        constants[0].viewMatrix = camera.getViewMatrix()
    }
    
    func render(in view: MTKView) throws {
        guard let commandQueue = self.commandQueue else {
            return
        }
        
        guard
//            let pipelineState = self.pipelineState,
            let wavePipelineState = self.wavePipelineState
        else {
            return
        }
        
//        guard let rectangle1 = rectangle1, let rectangle2 = rectangle2, let rectangle3 = rectangle3 else {
//            return
//        }
//
//        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        updateTexture(commandQueue: commandQueue);
        
        if frameConstants == nil {
            return
        }
        
        updateFrameConstants()
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "\(self.tripleBufferIndex)"
            
            if !tested {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    test?.run(computeEncoder: computeEncoder)
                    
                    computeEncoder.endEncoding()
                    
//                    tested = true
                }
            }
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    // Render stuff...
                    
//                    renderEncoder.setRenderPipelineState(pipelineState)
                    
//                    rectangle1.draw(renderEncoder: renderEncoder, sampler: sampler!)
//                    rectangle2.draw(renderEncoder: renderEncoder, sampler: sampler!)
//                    rectangle3.draw(renderEncoder: renderEncoder, sampler: sampler!)

                    renderEncoder.setRenderPipelineState(wavePipelineState)
                    
                    renderEncoder.setCullMode(.back)
                    
                    renderEncoder.setVertexBuffer(frameConstants, offset: 0, index: BufferIndex.frameConstants.rawValue)
                    
                    if Settings.shared.wireframe {
                        renderEncoder.setTriangleFillMode(.lines)
                    }
                    
                    renderEncoder.setVertexTexture(h0ktTexture[pingpong ^ 1], index: 3)

                    // Pass the vertex and index information to the vertex shader
                    for (i, buffer) in wave!.vertexBuffers.enumerated() {
                        renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: i)
                    }
                    
                    for submesh in wave!.submeshes {
                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset, instanceCount: 1)
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

//    func updateViewDimensions() {
//        /// Respond to drawable size or orientation changes here
//        let width = MetalView.shared.width
//        let height = MetalView.shared.height
//
//        if width != 0 && height != 0 {
//            let fovy: Float = degreesToRadians(45.0)
//            let aspect = Float(height) / Float(width)
//
//            self.projectionMatrix = Matrix4x4.perspectiveLeftHand(fovyRadians: fovy, aspect: aspect, nearZ: nearZ, farZ: farZ)
//        }
//    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        MetalView.shared.width = Float(size.width)
        MetalView.shared.height = Float(size.height)

        camera.updateViewDimensions()
    }
}

func allocatePlane(dimensions: simd_float2, segments: simd_uint2) throws -> MTKMesh {
    let meshBufferAllocator = MTKMeshBufferAllocator(device: MetalView.shared.device)

    let mesh = MDLMesh.newPlane(withDimensions: dimensions, segments: segments, geometryType: .triangles, allocator: meshBufferAllocator)

//    mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate, normalAttributeNamed: MDLVertexAttributeNormal, tangentAttributeNamed: MDLVertexAttributeTangent)

    mesh.vertexDescriptor = vertexDescriptor()
    
    return try MTKMesh(mesh: mesh, device: MetalView.shared.device)
}


func vertexDescriptor() -> MDLVertexDescriptor {
    let vertexDescriptor = MDLVertexDescriptor()
    
    var vertexAttributes = MDLVertexAttribute()
    vertexAttributes.name = MDLVertexAttributePosition
    vertexAttributes.format = .float3
    vertexAttributes.offset = 0
    vertexAttributes.bufferIndex = 0
    
    vertexDescriptor.attributes[0] = vertexAttributes
            
    vertexAttributes = MDLVertexAttribute()
    vertexAttributes.name = MDLVertexAttributeTextureCoordinate
    vertexAttributes.format = .float2
    vertexAttributes.offset = 0
    vertexAttributes.bufferIndex = 1
    
    vertexDescriptor.attributes[1] = vertexAttributes

//    vertexAttributes = MDLVertexAttribute()
//    vertexAttributes.name = MDLVertexAttributeNormal
//    vertexAttributes.format = .float3
//    vertexAttributes.offset = 0
//    vertexAttributes.bufferIndex = BufferIndex.normals.rawValue
//    vertexDescriptor.attributes[VertexAttribute.normal.rawValue] = vertexAttributes
//
//    vertexAttributes = MDLVertexAttribute()
//    vertexAttributes.name = MDLVertexAttributeTangent
//    vertexAttributes.format = .float3
//    vertexAttributes.offset = MemoryLayout<simd_float3>.stride
//    vertexAttributes.bufferIndex = BufferIndex.normals.rawValue
//    vertexDescriptor.attributes[VertexAttribute.tangent.rawValue] = vertexAttributes

    var vertexBufferLayout = MDLVertexBufferLayout()
    vertexBufferLayout.stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0] = vertexBufferLayout

    vertexBufferLayout = MDLVertexBufferLayout()
    vertexBufferLayout.stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1] = vertexBufferLayout
    
    return vertexDescriptor
}
