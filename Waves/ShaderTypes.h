//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#include <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex) {
    BufferIndexMeshPositions = 0,
    BufferIndexNormals = 1,
    BufferIndexFrameConstants = 2,
    BufferIndexModelMatrix = 3,
    BufferIndexNodeUniforms = 4,
    BufferIndexMaterialUniforms = 5,
    BufferIndexCascadeIndex = 7,
    BufferIndexReduction = 8,
    BufferIndexFinalReduction = 9,
    BufferIndexShadowCascadeMatrices = 10,
    BufferIndexArgumentBuffer = 11
};

struct FrameConstants {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
};

struct Params {
    vector_float2 windDirection;
    float windSpeed;
    int L;
    float A;
    float l;
};

struct InverseFFTParams {
    int stage;
    int lastStage;
};

#endif // ShaderTypes_h
