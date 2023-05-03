//
//  Butterfly.swift
//  Waves
//
//  Created by Richard Shields on 5/2/23.
//

import Foundation
import Metal

func makeButterflyTexture(N: Int, inverse: Bool, commandQueue: MTLCommandQueue) throws -> MTLTexture {
    let height = Int(log2(Float(N)))
    
    let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: N, height: height, mipmapped: false);
    textureDescr.usage = [.shaderWrite, .shaderRead]
    
    let butterflyTexture = MetalView.shared.device.makeTexture(descriptor: textureDescr)

    let library = MetalView.shared.device.makeDefaultLibrary()

    guard let function = library?.makeFunction(name: "makeButterflyTexture") else {
        throw Errors.makeFunctionError
    }
    
    if let pipeline = try? MetalView.shared.device.makeComputePipelineState(function: function) {
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                
                computeEncoder.setComputePipelineState(pipeline)
                
                computeEncoder.setTexture(butterflyTexture, index: 0)
                
                let threadsPerGrid = MTLSizeMake(N, height, 1)
                
                let width = pipeline.threadExecutionWidth
                let height = pipeline.maxTotalThreadsPerThreadgroup / width
                
                let threadsPerGroup = MTLSizeMake(width, height, 1)
                
                var inv = inverse
                computeEncoder.setBytes(&inv, length: MemoryLayout<Bool>.size, index: 0)
                
                computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
                
                computeEncoder.endEncoding()
                
                commandBuffer.commit()
            }
        }
    }
    
    return butterflyTexture!
}
