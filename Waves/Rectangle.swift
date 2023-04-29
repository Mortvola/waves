//
//  Rectangle.swift
//  Waves
//
//  Created by Richard Shields on 4/29/23.
//

import Foundation
import MetalKit

class Rectangle {
    private var vertices: MTLBuffer? = nil
    private var texcoords: MTLBuffer? = nil
    
    private var texture: MTLTexture
    
    init(texture: MTLTexture, offset: simd_float2) {
        self.texture = texture
        
        makeVertexPositions(offset: offset)
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder, sampler: MTLSamplerState) {
        renderEncoder.setVertexBuffer(vertices, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(texcoords, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    func makeVertexPositions(offset: simd_float2) {
        self.vertices = MetalView.shared.device.makeBuffer(length: MemoryLayout<simd_float3>.size * 6, options: .storageModeShared)
        let verts = UnsafeMutableRawPointer(self.vertices!.contents()).bindMemory(to: simd_float3.self, capacity: 6 * MemoryLayout<simd_float3>.size)
        
        verts[0] = simd_float3(offset.x + 0, offset.y + 0, 0)
        verts[1] = simd_float3(offset.x + 512, offset.y + 0, 0)
        verts[2] = simd_float3(offset.x + 0, offset.y + 512, 0)
        verts[3] = simd_float3(offset.x + 512, offset.y + 0, 0)
        verts[4] = simd_float3(offset.x + 512, offset.y + 512, 0)
        verts[5] = simd_float3(offset.x + 0, offset.y + 512, 0)

        self.texcoords = MetalView.shared.device.makeBuffer(length: MemoryLayout<simd_float2>.size * 6, options: .storageModeShared)
        let tex = UnsafeMutableRawPointer(self.texcoords!.contents()).bindMemory(to: simd_float2.self, capacity: 6 * MemoryLayout<simd_float2>.size)
        
        tex[0] = simd_float2(0, 0)
        tex[1] = simd_float2(1, 0)
        tex[2] = simd_float2(0, 1)
        tex[3] = simd_float2(1, 0)
        tex[4] = simd_float2(1, 1)
        tex[5] = simd_float2(0, 1)
    }
}
