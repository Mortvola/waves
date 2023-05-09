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
    let N: Int
    
//    var windspeed: Float
//    var windDirection: Float
    
    public var noiseTexture1: MTLTexture
    public var noiseTexture2: MTLTexture
    public var noiseTexture3: MTLTexture
    public var noiseTexture4: MTLTexture
    public var params: MTLBuffer
    
    private var h0ktexture: MTLTexture? = nil

    init(commandQueue: MTLCommandQueue, N: Int, windDirection: Float, windSpeed: Float) throws {
        self.N = N
        self.noiseTexture1 = try InputTexture.makeNoiseTexture(N: N, seed: 0)
        self.noiseTexture2 = try InputTexture.makeNoiseTexture(N: N, seed: 1)
        self.noiseTexture3 = try InputTexture.makeNoiseTexture(N: N, seed: 2)
        self.noiseTexture4 = try InputTexture.makeNoiseTexture(N: N, seed: 3)

        self.params = MetalView.shared.device.makeBuffer(length: MemoryLayout<Params>.size)!
        
//        self.windspeed = windSpeed
//        self.windDirection = windDirection
        
        makeTexture(commandQueue: commandQueue)
    }
    
    class func makeNoiseTexture(N: Int, seed: Int) throws -> MTLTexture {
        let noise = GKGaussianDistribution(randomSource: GKARC4RandomSource(seed: "\(seed)".data(using: .utf8)!), mean: 0, deviation: 1)

        guard let buffer = MetalView.shared.device.makeBuffer(length: N * N * MemoryLayout<Float>.size, options: .storageModeShared) else {
            throw Errors.makeFunctionError
        }
        
        let b = buffer.contents().bindMemory(to: Float.self, capacity: N * N * MemoryLayout<Float>.size)
        
        for i in 0..<N * N {
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
    
    func makeTexture(commandQueue: MTLCommandQueue) {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let function = library?.makeFunction(name: "makeInputTexture") else {
            return
        }
        
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: N, height: N, mipmapped: false);
        textureDescr.usage = [.shaderWrite, .shaderRead]
        
        h0ktexture = MetalView.shared.device.makeTexture(descriptor: textureDescr)
        
        if let pipeline = try? MetalView.shared.device.makeComputePipelineState(function: function) {
            
            if let commandBuffer = commandQueue.makeCommandBuffer() {
                if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                    
                    computeEncoder.setComputePipelineState(pipeline)
                    
                    let p = params.contents().bindMemory(to: Params.self, capacity: MemoryLayout<Params>.size)
                    p[0].windDirection = simd_float2(cos(Settings.shared.windDirection / 180 * Float.pi), sin(Settings.shared.windDirection / 360 * Float.pi))
                    p[0].windSpeed = Settings.shared.windspeed
                    p[0].L = Settings.shared.L
                    p[0].A = Settings.shared.A
                    p[0].l = Settings.shared.l

                    computeEncoder.setBuffer(params, offset: 0, index: 0)
                    computeEncoder.setTexture(noiseTexture1, index: 0)
                    computeEncoder.setTexture(noiseTexture2, index: 1)
                    computeEncoder.setTexture(noiseTexture3, index: 2)
                    computeEncoder.setTexture(noiseTexture4, index: 3)
                    computeEncoder.setTexture(h0ktexture, index: 4)
                    
                    let threadsPerGrid = MTLSizeMake(N, N, 1)
                    
                    let width = pipeline.threadExecutionWidth
                    let height = pipeline.maxTotalThreadsPerThreadgroup / width
                    
                    let threadsPerGroup = MTLSizeMake(width, height, 1)
                    
                    computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                    
                    computeEncoder.endEncoding()
                    
                    commandBuffer.commit()
                }
            }
        }
//
//        self.windspeed = windSpeed
//        self.windDirection = windDirection
    }
}
