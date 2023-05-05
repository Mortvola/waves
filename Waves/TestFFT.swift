//
//  TestFFT.swift
//  Waves
//
//  Created by Richard Shields on 5/1/23.
//

import Foundation
import Metal
import GameplayKit

class TestFFT {
    let N: Int
    
    private var testTexture: [MTLTexture] = []
    
    private var fft: Fourier
    
    init(N: Int, commandQueue: MTLCommandQueue) throws {
        self.N = N
        
        fft = try Fourier(M: N, N: N, commandQueue: commandQueue)
        
        testTexture.append(try makeTexture())
        testTexture.append(try makeTexture())
    }
    
    func run(computeEncoder: MTLComputeCommandEncoder) {
        
        do {
            testTexture[0] = try makeTexture()
            testTexture[1] = try makeTexture()
        }
        catch {}
        
        let pingpong = fft.horizontalFFT(computeEncoder: computeEncoder, data: testTexture, startingBuffer: 0)
        
        _ = fft.inverseHorizontalFFT(computeEncoder: computeEncoder, data: testTexture, startingBuffer: pingpong)
    }
    
    func makeTexture() throws -> MTLTexture {
        let t = Date().timeIntervalSince1970
        let random = GKARC4RandomSource(seed: "\(t)".data(using: .utf8)!)
        
        let length = N * MemoryLayout<simd_float2>.size
        guard let buffer = MetalView.shared.device.makeBuffer(length: length, options: .storageModeShared) else {
            throw Errors.makeFunctionError
        }
        
        let b = buffer.contents().bindMemory(to: simd_float2.self, capacity: N * MemoryLayout<simd_float2>.size)
        
//        print("------------------------")
//        let t1 = -8.0 * 2.0 * Float.pi
        for i in 0..<N {
//            let t: Float = t1 * Float(i) / Float(N)
            b[i].x = Float(i) // random.nextUniform()
            b[i].y = Float(i) // random.nextUniform()
            
//            print("\(b[i].x) + i\(b[i].y)")
        }
        
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: 1, mipmapped: false);
        textureDescr.storageMode = .shared
        textureDescr.usage = [.shaderRead, .shaderWrite]
        
        guard let texture = buffer.makeTexture(descriptor: textureDescr, offset: 0, bytesPerRow: length) else {
            throw Errors.makeFunctionError
        }

        return texture
    }
}
