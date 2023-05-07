//
//  FourierShaders.metal
//  Waves
//
//  Created by Richard Shields on 5/2/23.
//

#include <metal_stdlib>
#include "Complex.h"
#include "ShaderTypes.h"

using namespace metal;


uint reverseBits(uint n, uint length) {
    uint r = 0;
    
    for (uint i = 0; i < length; ++i) {
        r <<= 1;
        if ((n & 1) == 1) {
            r ^= 1;
        }
        
        n >>= 1;
    }
    
    return r;
}

kernel void makeButterflyTexture(
                                 texture2d<float, access::write> output [[ texture(0) ]],
                                 uint2 tpig [[ thread_position_in_grid ]]
                                 )
{
    int stage = tpig.y + 1;
    
    int lanesPerGroup = pow(2.0, stage);
    int index1 = tpig.x % (lanesPerGroup / 2) + (tpig.x / lanesPerGroup) * lanesPerGroup;
    int index2 = index1 + (lanesPerGroup / 2);
    
    int sign = 1;
    
    if (stage == 1) {
        uint length = log2(float(output.get_width()));
        index1 = reverseBits((tpig.x / 2) * 2, length);
        index2 = reverseBits((tpig.x / 2) * 2 + 1, length);

        if ((tpig.x & 1) == 1) {
            sign = -1;
        }
    }
    else {
        if (index2 == int(tpig.x)) {
            sign = -1;
        }
    }
    
    int groupButterflyIndex = tpig.x % (lanesPerGroup / 2);
    
    float theta = (2 * M_PI_F * groupButterflyIndex) / lanesPerGroup;
    
    // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
    float2 w = float2(cos(theta), sin(theta));
    w *= sign;
    
    output.write(float4(w.x, w.y, index1, index2), tpig);
}

kernel void horzFFTStage(
                         const device int &stage [[ buffer(0) ]],
                         texture2d<float, access::read> input [[ texture(0) ]],
                         texture2d<float, access::write> output [[ texture(1) ]],
                         texture2d<float, access::read> butterfly [[ texture(2) ]],
                         uint2 tpig [[ thread_position_in_grid ]]
                         )
{
    float4 lookup = butterfly.read(uint2(tpig.x, stage));
    
    float4 v1 = input.read(uint2(lookup.b, tpig.y));
    float4 v2 = input.read(uint2(lookup.a, tpig.y));
    
    float2 c1 = v1.rg + ComplexMultiply(lookup.rg, v2.rg);

    output.write(float4(c1.r, c1.g, 0, 1), tpig);
}

kernel void inverseHorzFFTStage(
                            const device InverseFFTParams &params [[ buffer(0) ]],
                            texture2d<float, access::read> input [[ texture(0) ]],
                            texture2d<float, access::write> output [[ texture(1) ]],
                            texture2d<float, access::read> butterfly [[ texture(2) ]],
                            uint2 tpig [[ thread_position_in_grid ]]
                            )
{
    float4 lookup = butterfly.read(uint2(tpig.x, params.stage));
    
    float4 v1 = input.read(uint2(lookup.b, tpig.y));
    float4 v2 = input.read(uint2(lookup.a, tpig.y));
    
//    if (params.stage == 0) {
//        v1 = float4(v1.r, -v1.g, 0, 1);
//        v2 = float4(v2.r, -v2.g, 0, 1);
//    }
    
    float2 c1 = v1.rg + ComplexMultiply(lookup.rg, v2.rg);

//    if (params.stage == params.lastStage) {
//        c1 = float2(c1.r, -c1.g);
//    }

    output.write(float4(c1.r, c1.g, 0, 1), tpig);
}

kernel void inverseVertFFTStage(
                            const device InverseFFTParams &params [[ buffer(0) ]],
                            texture2d<float, access::read> input [[ texture(0) ]],
                            texture2d<float, access::write> output [[ texture(1) ]],
                            texture2d<float, access::read> butterfly [[ texture(2) ]],
                            uint2 tpig [[ thread_position_in_grid ]]
                            )
{
    float4 lookup = butterfly.read(uint2(tpig.y, params.stage));
    
    float4 v1 = input.read(uint2(tpig.x, lookup.b));
    float4 v2 = input.read(uint2(tpig.x, lookup.a));

//    if (params.stage == 0) {
//        v1 = float4(v1.r, -v1.g, 0, 1);
//        v2 = float4(v2.r, -v2.g, 0, 1);
//    }

    float2 c1 = v1.rg + ComplexMultiply(lookup.rg, v2.rg);

//    if (params.stage == params.lastStage) {
//        c1 = float2(c1.r, -c1.g);
//    }

    output.write(float4(c1.x, c1.y, 0, 1), tpig);
}

kernel void inverseFFTDivide(
                             const device float &multiplier [[ buffer(0) ]],
                             texture2d<float, access::read_write> input [[ texture(0) ]],
                             uint2 tpig [[ thread_position_in_grid ]]
                             )
{
    float4 height = input.read(tpig);
    
    if ((tpig.y & 1) ^ (tpig.x & 1)) {
        height = -height;
    }

//    float2 result = ComplexMultiply(value.rg, float2(multiplier, 0));
    
    input.write(float4(height.rg, 0, 1), tpig);
}
