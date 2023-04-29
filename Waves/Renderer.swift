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

    private var vertices: MTLBuffer? = nil
    private var texcoords: MTLBuffer? = nil
    
    private var pipelineState: MTLRenderPipelineState? = nil
    
    private var h0ktexture: MTLTexture? = nil
    
    private var noise1: GKGaussianDistribution? = nil
    private var noise2: GKGaussianDistribution? = nil
    
    private var noiseTexture1: MTLTexture? = nil
    private var noiseTexture2: MTLTexture? = nil
    
    private var sampler: MTLSamplerState? = nil

    func initialize() throws {
        guard let queue = MetalView.shared.device.makeCommandQueue() else {
            throw Errors.makeCommandQueueFailed
        }
        
        self.commandQueue = queue
        
        makeVertexPositions();
        
        self.pipelineState = try makePipeline()
        
        self.sampler = try makeSampler()

        self.noise1 = GKGaussianDistribution(randomSource: GKARC4RandomSource(seed: "1".data(using: .utf8)!), mean: 0, deviation: 1)
        self.noise2 = GKGaussianDistribution(randomSource: GKARC4RandomSource(seed: "2".data(using: .utf8)!), mean: 0, deviation: 1)

        self.noiseTexture1 = try makeNoiseTexture()
        self.noiseTexture2 = try makeNoiseTexture()
//        phillipsSpectrum();
        
        buildComputePipeline()
    }
      
    func makeNoiseTexture() throws -> MTLTexture {
        let N = 512;
        
        let t = Date().timeIntervalSince1970
        
        let noise = GKGaussianDistribution(randomSource: GKARC4RandomSource(seed: "\(t)".data(using: .utf8)!), mean: 0, deviation: 1)

        guard let buffer = MetalView.shared.device.makeBuffer(length: N * N * MemoryLayout<Float>.size, options: .storageModeShared) else {
            throw Errors.makeFunctionError
        }
        
        let b = buffer.contents().bindMemory(to: Float.self, capacity: N * N * MemoryLayout<Float>.size)
        
        for i in 0..<512*512 {
            b[i] = noise.nextUniform()
        }
        
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: N, height: N, mipmapped: false);
        textureDescr.storageMode = .shared
        textureDescr.usage = .shaderRead
        
        guard let texture = buffer.makeTexture(descriptor: textureDescr, offset: 0, bytesPerRow: N * MemoryLayout<Float>.size) else {
            throw Errors.makeFunctionError
        }
        
        return texture;
    }
    
//    func phillipsSpectrum() {
//        let N = 512;
//
//        let buffer = MetalView.shared.device.makeBuffer(length: N * N * MemoryLayout<simd_float4>.size, options: .storageModeShared)
//        let b = buffer!.contents().bindMemory(to: simd_float4.self, capacity: N * N * MemoryLayout<simd_float4>.size)
//
//        let L = 1000
//
//        let A: Float = 20;
//
//        // Wind speed
//        let V: Float = 5
//        let w: simd_float2 = normalize(simd_float2(1, 1))
//
//        let g: Float = 9.8
//
//        let L2 = (V * V) / g;
//
//        let l: Float = 0.25;
//
//        var i = 0
//        for n in (-N / 2)..<(N / 2) {
//            for m in (-N / 2)..<(N / 2) {
//                let k: simd_float2 = simd_float2((2.0 * Float.pi * Float(n)) / Float(L), (2.0 * Float.pi * Float(m)) / Float(L))
//
//                var kLength = length(k)
//                var kdotw = dot(normalize(k), w)
//                var negKdotw = dot(normalize(-k), w)
//
//                if kLength == 0 {
//                    kLength = 0.00001
//                    kdotw = 0
//                    negKdotw = 0
//                }
//
//                var h0k = sqrt(
//                    (A / pow(kLength, 4))
//                    * exp(-1 / (kLength * kLength * L2 * L2))
//                    * pow(kdotw, 2)
//                    * exp(-kLength * kLength * l * l)
//                ) / sqrt(2)
//
//                if h0k.isNaN {
//                    h0k = 0
//                }
//
////                    let h0minusK = sqrt(A * (exp(-1 / pow(kLength * L2, 2)) / pow(kLength, 4)) * pow(negKdotw, 2)) / sqrt(2)
//
//                b[i] = simd_float4(h0k * noise1!.nextUniform(), h0k * noise2!.nextUniform(), 0, 1);
////                b[i] = simd_float4(h0k, h0k, 0, 1);
//                i += 1
//            }
//        }
//
//        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: N, height: N, mipmapped: false);
//        textureDescr.storageMode = .shared
//
//        h0ktexture = buffer?.makeTexture(descriptor: textureDescr, offset: 0, bytesPerRow: N * MemoryLayout<simd_float4>.size)
//    }
    
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

    func makeVertexPositions() {
        self.vertices = MetalView.shared.device.makeBuffer(length: MemoryLayout<simd_float3>.size * 6, options: .storageModeShared)
        let verts = UnsafeMutableRawPointer(self.vertices!.contents()).bindMemory(to: simd_float3.self, capacity: 6 * MemoryLayout<simd_float3>.size)
        
        verts[0] = simd_float3(0, 0, 0)
        verts[1] = simd_float3(512, 0, 0)
        verts[2] = simd_float3(0, 512, 0)
        verts[3] = simd_float3(512, 0, 0)
        verts[4] = simd_float3(512, 512, 0)
        verts[5] = simd_float3(0, 512, 0)

        self.texcoords = MetalView.shared.device.makeBuffer(length: MemoryLayout<simd_float2>.size * 6, options: .storageModeShared)
        let tex = UnsafeMutableRawPointer(self.texcoords!.contents()).bindMemory(to: simd_float2.self, capacity: 6 * MemoryLayout<simd_float2>.size)
        
        tex[0] = simd_float2(0, 0)
        tex[1] = simd_float2(1, 0)
        tex[2] = simd_float2(0, 1)
        tex[3] = simd_float2(1, 0)
        tex[4] = simd_float2(1, 1)
        tex[5] = simd_float2(0, 1)
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
    
    func buildComputePipeline() {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let function = library?.makeFunction(name: "test") else {
            return
        }
        
        let N = 512
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: N, height: N, mipmapped: false);
        textureDescr.usage = [.shaderWrite, .shaderRead]
        
        h0ktexture = MetalView.shared.device.makeTexture(descriptor: textureDescr)
        
        if let pipeline = try? MetalView.shared.device.makeComputePipelineState(function: function) {
            
            if let commandBuffer = commandQueue?.makeCommandBuffer() {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    
                    computeEncoder.setComputePipelineState(pipeline)
                    
                    computeEncoder.setTexture(noiseTexture1, index: 0)
                    computeEncoder.setTexture(noiseTexture2, index: 1)
                    computeEncoder.setTexture(h0ktexture, index: 2)
                    
                    let dimension = 512
                    let threadsPerGrid = MTLSizeMake(dimension, dimension, 1)
                    
                    let width = pipeline.threadExecutionWidth
                    let height = pipeline.maxTotalThreadsPerThreadgroup / width
                    
                    let threadsPerGroup = MTLSizeMake(width, height, 1)
                    
                    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                    
                    computeEncoder.endEncoding()
                    
                    commandBuffer.commit()
                }
            }
        }
    }
    

    func render(in view: MTKView) throws {
        guard let commandQueue = self.commandQueue else {
            return
        }
        
        guard let pipelineState = self.pipelineState else {
            return
        }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "\(self.tripleBufferIndex)"
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    // Render stuff...
                    
                    renderEncoder.setRenderPipelineState(pipelineState)
                    
                    renderEncoder.setVertexBuffer(vertices, offset: 0, index: 0)
                    renderEncoder.setVertexBuffer(texcoords, offset: 0, index: 1)
                    renderEncoder.setFragmentTexture(h0ktexture, index: 0)
                    renderEncoder.setFragmentSamplerState(sampler, index: 0)
                    
                    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                    
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
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
