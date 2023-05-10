//
//  Mesh.swift
//  Waves
//
//  Created by Richard Shields on 5/10/23.
//

import Foundation
import MetalKit

class Mesh {
    private var wave: MTKMesh? = nil

    init(N: Int) throws {
        wave = try allocatePlane(dimensions: simd_float2(Float(N * 2), Float(N * 2)), segments: simd_uint2(UInt32(N - 1), UInt32(N - 1)))
    }
    
    func allocatePlane(dimensions: simd_float2, segments: simd_uint2) throws -> MTKMesh {
        let meshBufferAllocator = MTKMeshBufferAllocator(device: MetalView.shared.device)

        let mesh = MDLMesh.newPlane(withDimensions: dimensions, segments: segments, geometryType: .triangles, allocator: meshBufferAllocator)

    //    mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate, normalAttributeNamed: MDLVertexAttributeNormal, tangentAttributeNamed: MDLVertexAttributeTangent)

        mesh.vertexDescriptor = vertexDescriptor()
        
        return try MTKMesh(mesh: mesh, device: MetalView.shared.device)
    }

    func vertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        
        var vertexAttributes = MDLVertexAttribute()
        vertexAttributes.name = MDLVertexAttributePosition
        vertexAttributes.format = .float3
        vertexAttributes.offset = 0
        vertexAttributes.bufferIndex = 0
        
        vertexDescriptor.attributes[0] = vertexAttributes
                
        vertexAttributes = MDLVertexAttribute()
        vertexAttributes.name = MDLVertexAttributeTextureCoordinate
        vertexAttributes.format = .float2
        vertexAttributes.offset = 0
        vertexAttributes.bufferIndex = 1
        
        vertexDescriptor.attributes[1] = vertexAttributes

        var vertexBufferLayout = MDLVertexBufferLayout()
        vertexBufferLayout.stride = MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[0] = vertexBufferLayout

        vertexBufferLayout = MDLVertexBufferLayout()
        vertexBufferLayout.stride = MemoryLayout<simd_float2>.stride
        vertexDescriptor.layouts[1] = vertexBufferLayout
        
        return vertexDescriptor
    }
    
    func draw(renderEncoder: MTLRenderCommandEncoder) {
        // Pass the vertex and index information to the vertex shader
        for (i, buffer) in wave!.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: i)
        }
        
        for submesh in wave!.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer, indexBufferOffset: submesh.indexBuffer.offset, instanceCount: 1)
        }
    }
    
    func getNormalLines() -> MTLBuffer {
        var totalVertices = 0
        
        for (i, buffer) in wave!.vertexBuffers.enumerated() {
            if i == 0 {
                totalVertices += (buffer.buffer.length - buffer.offset) / MemoryLayout<simd_float3>.size
            }
        }
        
        let vertices = MetalView.shared.device.makeBuffer(length: MemoryLayout<simd_float3>.size * totalVertices * 2, options: .storageModeShared)
        let verts = UnsafeMutableRawPointer(vertices!.contents()).bindMemory(to: simd_float3.self, capacity: totalVertices * 2 * MemoryLayout<simd_float3>.size)
        
        var normalVerts = 0

        for (i, buffer) in wave!.vertexBuffers.enumerated() {
            if i == 0 {
                let length = (buffer.buffer.length - buffer.offset) / MemoryLayout<simd_float3>.size
                let meshVerts = UnsafeMutableRawPointer(buffer.buffer.contents().advanced(by: buffer.offset)).bindMemory(to: simd_float3.self, capacity: length * MemoryLayout<simd_float3>.size)
                
                for i in 0..<length {
                    verts[normalVerts] = meshVerts[i]
                    verts[normalVerts + 1] = meshVerts[i]
                    
                    normalVerts += 2
                }
            }
        }
        
        return vertices!
    }
}
