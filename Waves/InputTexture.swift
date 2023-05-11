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
    
    public var noiseTexture1: MTLTexture
    public var noiseTexture2: MTLTexture
    public var noiseTexture3: MTLTexture
    public var noiseTexture4: MTLTexture
    
    private var h0ktexture: MTLTexture? = nil

    init(commandQueue: MTLCommandQueue, N: Int) throws {
        self.N = N
        self.noiseTexture1 = try InputTexture.makeNoiseTexture(N: N, seed: 0)
        self.noiseTexture2 = try InputTexture.makeNoiseTexture(N: N, seed: 1)
        self.noiseTexture3 = try InputTexture.makeNoiseTexture(N: N, seed: 2)
        self.noiseTexture4 = try InputTexture.makeNoiseTexture(N: N, seed: 3)
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
}
