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
    private var N: Int
    
    private var butterflyTexture: MTLTexture
    private var inverseButterflyTexture: MTLTexture

    private var testTexture: [MTLTexture] = []
    
    private var horzFFTPipeline: MTLComputePipelineState? = nil
    
    private var inverseHorzFFTPipeline: MTLComputePipelineState? = nil
    
    private var inverseFFTDividePipeline: MTLComputePipelineState? = nil
    
    init(N: Int, commandQueue: MTLCommandQueue) throws {
        self.N = N
        
        butterflyTexture = try makeButterflyTexture(N: N, inverse: false, commandQueue: commandQueue)
        inverseButterflyTexture = try makeButterflyTexture(N: N, inverse: true, commandQueue: commandQueue)

        testTexture.append(try makeTexture())
        testTexture.append(try makeTexture())
        
        try makeInverseFFTPipelines()
    }
    
    func makeInverseFFTPipelines() throws {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let horzFunction = library?.makeFunction(name: "horzFFTStage") else {
            return
        }

        horzFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: horzFunction)

        guard let inverseHorzFunction = library?.makeFunction(name: "inverseHorzFFTStage") else {
            return
        }
        
        inverseHorzFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseHorzFunction)

        guard let inverseFFTDivide = library?.makeFunction(name: "inverseFFTDivide") else {
            return
        }
        
        inverseFFTDividePipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseFFTDivide)
    }
    
    func run(computeEncoder: MTLComputeCommandEncoder) {
        
        do {
            testTexture[0] = try makeTexture()
            testTexture[1] = try makeTexture()
        }
        catch {}
        
        // Perform horizontal FFT
        computeEncoder.setComputePipelineState(horzFFTPipeline!)
        
        computeEncoder.setTexture(butterflyTexture, index: 2)
        
        let stages = Int(log2(Float(N)))
        
        let threadsPerGrid = MTLSizeMake(N, 1, 1)

        let width = horzFFTPipeline!.threadExecutionWidth
        let height = horzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = 0
        
        for stage in 0..<stages {
            computeEncoder.setTexture(testTexture[pingpong], index: 0)
            computeEncoder.setTexture(testTexture[pingpong ^ 1], index: 1)
            
            var s: Int = stage
            computeEncoder.setBytes(&s, length: MemoryLayout<Int>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }

        // Perform horizontal inverse FFT
        computeEncoder.setComputePipelineState(inverseHorzFFTPipeline!)
        
        computeEncoder.setTexture(inverseButterflyTexture, index: 2)
        
        for stage in 0..<stages {
            computeEncoder.setTexture(testTexture[pingpong], index: 0)
            computeEncoder.setTexture(testTexture[pingpong ^ 1], index: 1)
            
            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))
            
            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
        
        computeEncoder.setComputePipelineState(inverseFFTDividePipeline!)

        var multiplier = 1.0 / Float(N)

        computeEncoder.setBytes(&multiplier, length: MemoryLayout<Float>.size, index: 0)
        computeEncoder.setTexture(testTexture[pingpong], index: 0)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
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
