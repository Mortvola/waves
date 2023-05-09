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

kernel void fftPostProcess(
                             texture2d<float, access::read_write> input [[ texture(0) ]],
                             uint2 tpig [[ thread_position_in_grid ]]
                             )
{
    float4 height = input.read(tpig);
    
    if ((tpig.y & 1) ^ (tpig.x & 1)) {
        height = -height;
    }

    input.write(float4(height.rg, 0, 1), tpig);
}


float2 h(
         float2 k,
         float t,
         const device Params &params,
         float2 noise1,
         float2 noise2
         );

kernel void makeTimeTexture2(
                            const device Params &params [[ buffer(0) ]],
                            const device float &t [[ buffer(1) ]],
                            texture2d<float, access::read> noise1 [[ texture(0) ]],
                            texture2d<float, access::read> noise2 [[ texture(1) ]],
                            texture2d<float, access::read> noise3 [[ texture(2) ]],
                            texture2d<float, access::read> noise4 [[ texture(3) ]],
                            texture2d<float, access::write> height [[ texture(4) ]],
                            texture2d<float, access::write> dx [[ texture(5) ]],
                            texture2d<float, access::write> dz [[ texture(6) ]],
                            texture2d<float, access::write> slopeX [[ texture(7) ]],
                            texture2d<float, access::write> slopeZ [[ texture(8) ]],
                            uint2 tpig [[ thread_position_in_grid ]]
                            )
{
    int M = height.get_width();
    
    int m = tpig.x - M/2;
    int n = tpig.y - M/2;

    float ns1 = noise1.read(uint2(m + (M/2), n + (M/2))).r;
    float ns2 = noise2.read(uint2(m + (M/2), n + (M/2))).r;
    float ns3 = noise3.read(uint2(m + (M/2), n + (M/2))).r;
    float ns4 = noise4.read(uint2(m + (M/2), n + (M/2))).r;
     
    float2 noiseA = float2(ns1, ns2);
    float2 noiseB = float2(ns3, ns4);

    float2 k = simd_float2((M_PI_F * 2 * float(m)) / float(params.L), (M_PI_F * 2 * float(n)) / float(params.L));
    float2 v = h(k, t, params, noiseA, noiseB);
    
    if (((tpig.x & 1) ^ (tpig.y & 1)) == 1) {
        v = -v;
    }

    height.write(float4(v.x, v.y, 0, 1), tpig);
    
    float kLength = length(k);
    
    float2 dispX = 0;
    float2 dispZ = 0;

    if (params.xzDisplacement) {
        if (kLength != 0) {
            dispX = ComplexMultiply(v, float2(0, -k.x / kLength));
        }
        
        if (kLength != 0) {
            dispZ = ComplexMultiply(v, float2(0, -k.y / kLength));
        }
    }

    dx.write(float4(dispX.x, dispX.y, 0, 1), tpig);
    dz.write(float4(dispZ.x, dispZ.y, 0, 1), tpig);
    
    float2 nX = ComplexMultiply(v, float2(0, k.x));
    float2 nZ = ComplexMultiply(v, float2(0, k.y));
    
    slopeX.write(float4(nX.x, nX.y, 0, 1), tpig);
    slopeZ.write(float4(nZ.x, nZ.y, 0, 1), tpig);
}

kernel void horizontalFFTStage(
                          const device int &stage [[ buffer(0) ]],
                          texture2d<float, access::read> input [[ texture(0) ]],
                          texture2d<float, access::write> output [[ texture(1) ]],
                          uint2 tpig [[ thread_position_in_grid ]]
                          )
{
    int lanesPerGroup = pow(2, float(stage + 1));
    int M = input.get_width();

    int sign = 1;
    
    uint x = tpig.x;
    uint y = tpig.y;
    
    int index1 = 0;
    int index2 = 0;

    if (stage == 0) {
        int length = log2(float(M));
        
        index1 = reverseBits((x / 2) * 2, length);
        index2 = reverseBits((x / 2) * 2 + 1, length);

        if ((x & 1) == 1) {
            sign = -1;
        }
    }
    else {
        index1 = x % (lanesPerGroup / 2) + (x / lanesPerGroup) * lanesPerGroup;
        index2 = index1 + (lanesPerGroup / 2);

        if (index2 == int(x)) {
            sign = -1;
        }
    }
    
    int groupButterflyIndex = x % (lanesPerGroup / 2);
    float theta = (2.0 * M_PI_F * float(groupButterflyIndex)) / float(lanesPerGroup);
    
    // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
    float2 w = float2(cos(theta), sin(theta)) * sign;
    
    float2 v1 = input.read(uint2(index1, y)).rg;
    float2 v2 = input.read(uint2(index2, y)).rg;

    float2 v = v1 + ComplexMultiply(v2, w);
    
    output.write(float4(v.x, v.y, 0, 1), tpig);
}


kernel void verticalFFTStage(
                          const device int &stage [[ buffer(0) ]],
                          texture2d<float, access::read> input [[ texture(0) ]],
                          texture2d<float, access::write> output [[ texture(1) ]],
                          uint2 tpig [[ thread_position_in_grid ]]
                          )
{
    int lanesPerGroup = pow(2, float(stage + 1));
    int M = input.get_height();
    
    int sign = 1;
    
    uint x = tpig.x;
    uint y = tpig.y;
    
    int index1 = 0;
    int index2 = 0;
    
    if (stage == 0) {
        int length = log2(float(M));
        
        index1 = reverseBits((y / 2) * 2, length);
        index2 = reverseBits((y / 2) * 2 + 1, length);
        
        if ((y & 1) == 1) {
            sign = -1;
        }
    }
    else {
        index1 = y % (lanesPerGroup / 2) + (y / lanesPerGroup) * lanesPerGroup;
        index2 = index1 + (lanesPerGroup / 2);

        if (index2 == int(y)) {
            sign = -1;
        }
    }
    
    int groupButterflyIndex = y % (lanesPerGroup / 2);
    float theta = (2.0 * M_PI_F * float(groupButterflyIndex)) / float(lanesPerGroup);
    
    // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
    float2 w = float2(cos(theta), sin(theta)) * sign;
    
    float2 v1 = input.read(uint2(x, index1)).rg;
    float2 v2 = input.read(uint2(x, index2)).rg;

    float2 v = v1 + ComplexMultiply(v2, w);
    
    output.write(float4(v.x, v.y, 0, 1), tpig);
}
