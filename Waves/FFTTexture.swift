//
//  FFTTexture.swift
//  Waves
//
//  Created by Richard Shields on 5/9/23.
//

import Foundation
import Metal

class FFTTexture {
    private var textures: [MTLTexture] = []
    private var pingpong = 0
    
    private var N: Int
    
    private var horizontalFFTPipeline: MTLComputePipelineState
    private var verticalFFTPipeline: MTLComputePipelineState
    private var fftPostProcessPipeline: MTLComputePipelineState

    //    private var butterflyTexture: MTLTexture
                
    init(N: Int, commandQueue: MTLCommandQueue) throws {
        self.N = N
        
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let inverseHorzFunction = library?.makeFunction(name: "horizontalFFTStage") else {
            throw Errors.makeFunctionError
        }
        
        horizontalFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseHorzFunction)

        guard let vertFunction = library?.makeFunction(name: "verticalFFTStage") else {
            throw Errors.makeFunctionError
        }

        verticalFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: vertFunction)

        guard let fftPostProcess = library?.makeFunction(name: "fftPostProcess") else {
            throw Errors.makeFunctionError
        }
        
        fftPostProcessPipeline = try MetalView.shared.device.makeComputePipelineState(function: fftPostProcess)

        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: N, mipmapped: false);
        textureDescr.usage = [.shaderWrite, .shaderRead]
        
        //        butterflyTexture = try makeButterflyTexture(N: N, inverse: false, commandQueue: commandQueue)

        textures.append(MetalView.shared.device.makeTexture(descriptor: textureDescr)!)
        textures.append(MetalView.shared.device.makeTexture(descriptor: textureDescr)!)
    }
    
    var texture: MTLTexture {
        textures[pingpong]
    }
    
    func transform(computeEncoder: MTLComputeCommandEncoder) {
        horizontalFFT(computeEncoder: computeEncoder)
        verticalFFT(computeEncoder: computeEncoder)
        
        fftPostProcess(computeEncoder: computeEncoder)
    }
    
    private func horizontalFFT(computeEncoder: MTLComputeCommandEncoder) {
        // Perform horizontal inverse FFT
        computeEncoder.setComputePipelineState(horizontalFFTPipeline)
        
//        computeEncoder.setTexture(inverseButterflyTexture, index: 2)
        
        let stages = Int(log2(Float(N)))

        let threadsPerGrid = MTLSizeMake(N, N, 1)

        let width = horizontalFFTPipeline.threadExecutionWidth
        let height = horizontalFFTPipeline.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        for stage in 0..<stages {
            computeEncoder.setTexture(textures[pingpong], index: 0)
            computeEncoder.setTexture(textures[pingpong ^ 1], index: 1)
            
            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))
            
            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
    }
    
    private func verticalFFT(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(verticalFFTPipeline)

//        computeEncoder.setTexture(inverseButterflyTexture, index: 2)

        let stages = Int(log2(Float(N)))

        let threadsPerGrid = MTLSizeMake(N, N, 1)

        let width = verticalFFTPipeline.threadExecutionWidth
        let height = verticalFFTPipeline.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        for stage in 0..<stages {
            computeEncoder.setTexture(textures[pingpong], index: 0)
            computeEncoder.setTexture(textures[pingpong ^ 1], index: 1)

            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))

            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
    }
    
    private func fftPostProcess(computeEncoder: MTLComputeCommandEncoder) {
        computeEncoder.setComputePipelineState(fftPostProcessPipeline)

        let threadsPerGrid = MTLSizeMake(N, N, 1)
        
        let width = fftPostProcessPipeline.threadExecutionWidth
        let height = fftPostProcessPipeline.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        computeEncoder.setTexture(texture, index: 0)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
    }
}
