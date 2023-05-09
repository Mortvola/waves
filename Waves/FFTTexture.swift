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
    
    private var fft: Fourier
    
    init(N: Int, commandQueue: MTLCommandQueue) throws {
        fft = try Fourier(M: N, N: N, commandQueue: commandQueue)
        
        let textureDescr = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: N, height: N, mipmapped: false);
        textureDescr.usage = [.shaderWrite, .shaderRead]
        
        textures.append(MetalView.shared.device.makeTexture(descriptor: textureDescr)!)
        textures.append(MetalView.shared.device.makeTexture(descriptor: textureDescr)!)
    }
    
    var texture: MTLTexture {
        textures[pingpong]
    }
    
    func transform(computeEncoder: MTLComputeCommandEncoder) {
        pingpong = fft.inverseHorizontalFFT(computeEncoder: computeEncoder, data: textures, startingBuffer: 0)
        pingpong = fft.inverseVerticalFFT(computeEncoder: computeEncoder, data: textures, startingBuffer: pingpong)
    }
}
