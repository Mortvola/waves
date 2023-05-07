//
//  Fourier.swift
//  Waves
//
//  Created by Richard Shields on 5/3/23.
//

import Foundation
import Metal

class Fourier {
    private var M: Int
    private var N: Int
    
    private var butterflyTexture: MTLTexture
    private var inverseButterflyTexture: MTLTexture

    private var horzFFTPipeline: MTLComputePipelineState? = nil
    
    private var inverseHorzFFTPipeline: MTLComputePipelineState? = nil
    private var inverseVertFFTPipeline: MTLComputePipelineState? = nil

    private var inverseFFTDividePipeline: MTLComputePipelineState? = nil
    
    init(M: Int, N: Int, commandQueue: MTLCommandQueue) throws {
        self.M = M
        self.N = N

        butterflyTexture = try makeButterflyTexture(N: N, inverse: false, commandQueue: commandQueue)
        inverseButterflyTexture = try makeButterflyTexture(N: N, inverse: true, commandQueue: commandQueue)
        
        try makeFFTPipelines()
    }
    
    func makeFFTPipelines() throws {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let horzFunction = library?.makeFunction(name: "horzFFTStage") else {
            return
        }

        horzFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: horzFunction)

        guard let inverseHorzFunction = library?.makeFunction(name: "inverseHorzFFTStage") else {
            return
        }
        
        inverseHorzFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseHorzFunction)

        guard let vertFunction = library?.makeFunction(name: "inverseVertFFTStage") else {
            return
        }

        inverseVertFFTPipeline = try? MetalView.shared.device.makeComputePipelineState(function: vertFunction)

        guard let inverseFFTDivide = library?.makeFunction(name: "inverseFFTDivide") else {
            return
        }
        
        inverseFFTDividePipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseFFTDivide)
    }
    

    func FFT() {
        
    }
    
    func horizontalFFT(computeEncoder: MTLComputeCommandEncoder, data: [MTLTexture], startingBuffer: Int) -> Int {
        // Perform horizontal FFT
        computeEncoder.setComputePipelineState(horzFFTPipeline!)
        
        computeEncoder.setTexture(butterflyTexture, index: 2)
        
        let stages = Int(log2(Float(M)))
        
        let threadsPerGrid = MTLSizeMake(M, N, 1)

        let width = horzFFTPipeline!.threadExecutionWidth
        let height = horzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = startingBuffer
        
        for stage in 0..<stages {
            computeEncoder.setTexture(data[pingpong], index: 0)
            computeEncoder.setTexture(data[pingpong ^ 1], index: 1)
            
            var s: Int = stage
            computeEncoder.setBytes(&s, length: MemoryLayout<Int>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
        
        return pingpong;
    }
    
    func inverseHorizontalFFT(computeEncoder: MTLComputeCommandEncoder, data: [MTLTexture], startingBuffer: Int) -> Int {
        // Perform horizontal inverse FFT
        computeEncoder.setComputePipelineState(inverseHorzFFTPipeline!)
        
        computeEncoder.setTexture(inverseButterflyTexture, index: 2)
        
        let stages = Int(log2(Float(M)))

        let threadsPerGrid = MTLSizeMake(M, N, 1)

        let width = inverseHorzFFTPipeline!.threadExecutionWidth
        let height = inverseHorzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = startingBuffer

        for stage in 0..<stages {
            computeEncoder.setTexture(data[pingpong], index: 0)
            computeEncoder.setTexture(data[pingpong ^ 1], index: 1)
            
            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))
            
            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
        
//        inverseFFTDivide(computeEncoder: computeEncoder, data: data[pingpong])
        
        return pingpong
    }
    
    func inverseVerticalFFT(computeEncoder: MTLComputeCommandEncoder, data: [MTLTexture], startingBuffer: Int) -> Int {
        computeEncoder.setComputePipelineState(inverseVertFFTPipeline!)

        computeEncoder.setTexture(inverseButterflyTexture, index: 2)

        let stages = Int(log2(Float(M)))

        let threadsPerGrid = MTLSizeMake(M, N, 1)

        let width = inverseHorzFFTPipeline!.threadExecutionWidth
        let height = inverseHorzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = startingBuffer

        for stage in 0..<stages {
            computeEncoder.setTexture(data[pingpong], index: 0)
            computeEncoder.setTexture(data[pingpong ^ 1], index: 1)

            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))

            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }

        inverseFFTDivide(computeEncoder: computeEncoder, data: data[pingpong])
        
        return pingpong
    }
    
    func inverseFFTDivide(computeEncoder: MTLComputeCommandEncoder, data: MTLTexture) {
        computeEncoder.setComputePipelineState(inverseFFTDividePipeline!)

        let threadsPerGrid = MTLSizeMake(M, N, 1)
        
        let width = inverseFFTDividePipeline!.threadExecutionWidth
        let height = inverseFFTDividePipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var multiplier = 1.0 / Float(N)

        computeEncoder.setBytes(&multiplier, length: MemoryLayout<Float>.size, index: 0)
        computeEncoder.setTexture(data, index: 0)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
    }
}
