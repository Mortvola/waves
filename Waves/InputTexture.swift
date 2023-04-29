//
//  InputTexture.swift
//  Waves
//
//  Created by Richard Shields on 4/29/23.
//

import Foundation
import Metal
import GameplayKit

class InputTexture {
    let N = 512;
    
    private var noiseTexture1: MTLTexture
    private var noiseTexture2: MTLTexture
    private var params: MTLBuffer
    
    var h0ktexture: MTLTexture? = nil

    init(commandQueue: MTLCommandQueue, windDirection: simd_float2) throws {
        self.noiseTexture1 = try InputTexture.makeNoiseTexture(N: N)
        self.noiseTexture2 = try InputTexture.makeNoiseTexture(N: N)
        
        self.params = MetalView.shared.device.makeBuffer(length: MemoryLayout<simd_float2>.size)!
        
        makeTexture(commandQueue: commandQueue, windDirection: windDirection)
    }
    
    class func makeNoiseTexture(N: Int) throws -> MTLTexture {
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
    
    func makeTexture(commandQueue: MTLCommandQueue, windDirection: simd_float2) {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let function = library?.makeFunction(name: "makeInputTexture") else {
            return
        }
        
        let N = 512
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: N, mipmapped: false);
        textureDescr.usage = [.shaderWrite, .shaderRead]
        
        h0ktexture = MetalView.shared.device.makeTexture(descriptor: textureDescr)
        
        if let pipeline = try? MetalView.shared.device.makeComputePipelineState(function: function) {
            
            if let commandBuffer = commandQueue.makeCommandBuffer() {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    
                    computeEncoder.setComputePipelineState(pipeline)
                    
                    let p = params.contents().bindMemory(to: simd_float2.self, capacity: MemoryLayout<simd_float2>.size)
                    p[0] = windDirection
                    
                    computeEncoder.setBuffer(params, offset: 0, index: 0)
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
}
