//
//  Shaders.metal
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

#include <metal_stdlib>
#include "ShaderTypes.h"
#include "Complex.h"

using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 texcoord;
    float3 normal;
};

void getWavePoint(
                  int x,
                  int y,
                  float3 originalPosition,
                  texture2d<float, access::read> height,
                  texture2d<float, access::read> displacementX,
                  texture2d<float, access::read> displacementZ,
                  texture2d<float, access::read> slopeX,
                  texture2d<float, access::read> slopeZ,
                  thread float3 &position,
                  thread float3 &normal)
{
    float4 h = height.read(uint2(x, y));
    float4 dispX = displacementX.read(uint2(x, y));
    float4 dispZ = displacementZ.read(uint2(x, y));
    float4 sX = slopeX.read(uint2(x, y));
    float4 sZ = slopeZ.read(uint2(x, y));

    float lambda = -1;
    
    position = float3(
                      originalPosition.x + dispX.r * lambda,
                      originalPosition.y + h.x,
                      originalPosition.z + dispZ.r * lambda);
    
    normal = normalize(float3(0 - sX.r, 1, 0 - sZ.r));
}

vertex VertexOut vertexWaveShader(
                                  VertexIn in [[ stage_in ]],
                                  const device FrameConstants& frameConstants [[ buffer(BufferIndexFrameConstants) ]],
                                  uint vertexId [[ vertex_id ]],
                                  texture2d<float, access::read> height [[ texture(3) ]],
                                  texture2d<float, access::read> displacementX [[ texture(4) ]],
                                  texture2d<float, access::read> displacementZ [[ texture(5) ]],
                                  texture2d<float, access::read> slopeX [[ texture(6) ]],
                                  texture2d<float, access::read> slopeZ [[ texture(7) ]]
                                  )
{
    VertexOut out;
    
    int x = vertexId % height.get_width();
    int y = vertexId / height.get_width();
    
    float3 p;
    float3 normal;
    
    getWavePoint(x, y, in.position, height, displacementX, displacementZ, slopeX, slopeZ, p, normal);
    
    out.position = frameConstants.projectionMatrix * frameConstants.viewMatrix * float4(p, 1);
    out.texcoord = in.texcoord;

    out.normal = normal;
    
    return out;
}

fragment float4 fragmentWaterShader(
                                    VertexOut in [[ stage_in ]],
                                    const device float4 &color [[ buffer(0) ]]
                                    )
{
    float3 light = normalize(float3(0, 1, -1));
    
    float d = dot(light, in.normal);
    
    float3 c = pow(color.rgb, float3(2.2));

    c = c * d;
    
    // HDR tonemapping
//    c = c / (c + float3(1.0));
    float exposure = 5.0;
    c = float3(1.0) - exp(-c * exposure);

    // gamma correct
//    c = pow(c, float3(1.0 / 2.2));

    return float4(c.rgb, 1);
}

struct NormalVertexIn {
    float3 position [[attribute(0)]];
};

vertex VertexOut vertexNormalsShader(
                                     NormalVertexIn in [[ stage_in ]],
                                     const device FrameConstants& frameConstants [[ buffer(BufferIndexFrameConstants) ]],
                                     uint vertexId [[ vertex_id ]],
                                     texture2d<float, access::read> height [[ texture(3) ]],
                                     texture2d<float, access::read> displacementX [[ texture(4) ]],
                                     texture2d<float, access::read> displacementZ [[ texture(5) ]],
                                     texture2d<float, access::read> slopeX [[ texture(6) ]],
                                     texture2d<float, access::read> slopeZ [[ texture(7) ]]
                                     )
{
    VertexOut out;

    int x = (vertexId / 2) % height.get_width();
    int y = (vertexId / 2) / height.get_width();
    
    float3 p;
    float3 normal;
    
    getWavePoint(x, y, in.position, height, displacementX, displacementZ, slopeX, slopeZ, p, normal);
    
    if ((vertexId & 1) == 1) {
        p += normal * 1.0;
    }
    
    out.position = frameConstants.projectionMatrix * frameConstants.viewMatrix * float4(p, 1);

    return out;
}

struct WireframeVertexOut {
    float4 position [[ position ]];
};

vertex WireframeVertexOut vertexWireframeShader(
                                  VertexIn in [[ stage_in ]],
                                  const device FrameConstants& frameConstants [[ buffer(BufferIndexFrameConstants) ]],
                                  uint vertexId [[ vertex_id ]],
                                  texture2d<float, access::read> height [[ texture(3) ]],
                                  texture2d<float, access::read> displacementX [[ texture(4) ]],
                                  texture2d<float, access::read> displacementZ [[ texture(5) ]],
                                  texture2d<float, access::read> slopeX [[ texture(6) ]],
                                  texture2d<float, access::read> slopeZ [[ texture(7) ]]
                                  )
{
    WireframeVertexOut out;
    
    int x = vertexId % height.get_width();
    int y = vertexId / height.get_width();
    
    float3 p;
    float3 normal;
    
    getWavePoint(x, y, in.position, height, displacementX, displacementZ, slopeX, slopeZ, p, normal);
    
    out.position = frameConstants.projectionMatrix * frameConstants.viewMatrix * float4(p, 1);
    
    return out;
}

fragment float4 fragmentColorShader(
                                        const device float4 &color [[ buffer(0) ]]
                                        )
{
    return color;
}

kernel void makeInputTexture(
                             const device Params &params [[ buffer(0) ]],
                             texture2d<float, access::read> noise1 [[ texture(0) ]],
                             texture2d<float, access::read> noise2 [[ texture(1) ]],
                             texture2d<float, access::read> noise3 [[ texture(2) ]],
                             texture2d<float, access::read> noise4 [[ texture(3) ]],
                             texture2d<float, access::write> output [[ texture(4) ]],
                             uint2 tpig [[ thread_position_in_grid ]]
                             )
{
    float A = params.A;
    float L = params.L;
    float N = output.get_width();
    
    float g = 9.8; // meters per second^2
    float L2 = (params.windSpeed * params.windSpeed) / g; // (m^2 / s) * (s^2 / m) --> meter seconds
    
    int mPrime = tpig.x;
    int nPrime = tpig.y;

    if ((tpig.x & 1) == 1) {
        mPrime += 1;
    }

    if ((tpig.y & 1) == 1) {
        nPrime += 1;
    }

    float2 k = float2(M_PI_F * (2 * mPrime - N) / L, M_PI_F * (2 * nPrime - N) / L);

    if ((tpig.x & 1) == 1) {
        k.x = M_PI_F * (2 * mPrime + 1 - N) / L;
    }

    if ((tpig.y & 1) == 1) {
        k.y = M_PI_F * (2 * nPrime + 1 - N) / L;
    }
    
    float kLength = length(k);
    
    float2 h0k1 = float2(0, 0);
    float2 h0k2 = float2(0, 0);
    
    if (kLength != 0) {
        float n1 = noise1.read(tpig).r;
        float n2 = noise2.read(tpig).r;
        float n3 = noise3.read(tpig).r;
        float n4 = noise4.read(tpig).r;

        float2 noise1 = float2(n1, n2);
        float2 noise2 = float2(n3, n4);

        float kdotw = dot(normalize(k), params.windDirection);
        
        float damping = params.l;
        
        float phk = (A
            * exp(-1 / (kLength * kLength * L2 * L2))
            / pow(kLength, 4))
            * pow(kdotw, 2)
            * exp(-kLength * kLength * damping * damping);
        
        h0k1 = sqrt(phk / 2.0) * noise1;
        
        kdotw = dot(normalize(k), -params.windDirection);
        
        phk = (A
            * exp(-1 / (kLength * kLength * L2 * L2))
            / pow(kLength, 4))
            * pow(kdotw, 2)
            * exp(-kLength * kLength * damping * damping);
        
        h0k2 = sqrt(phk) * noise2 / sqrt(2.0);
    }
    
    output.write(float4(h0k1.x, h0k1.y, h0k2.x, h0k2.y), tpig);
}

kernel void makeTimeTexture(
                            const device Params &params [[ buffer(0) ]],
                            const device float &t [[ buffer(1) ]],
                            texture2d<float, access::read> input [[ texture(0) ]],
                            texture2d<float, access::write> output [[ texture(1) ]],
                            uint2 tpig [[ thread_position_in_grid ]]
                           )
{
    float4 h0k = input.read(ushort2(tpig.x, tpig.y));
    
    float L = params.L;
    float N = input.get_width();

    int mPrime = tpig.x; //  - N / 2;
    int nPrime = tpig.y; //  - N / 2;

    if ((tpig.x & 1) == 1) {
        mPrime += 1;
    }

    if ((tpig.y & 1) == 1) {
        nPrime += 1;
    }

    float g = 9.8; // meters per second^2
    
    float kx = M_PI_F * (2 * mPrime - N) / L;
    float kz = M_PI_F * (2 * nPrime - N) / L;

    if ((mPrime & 1) == 1) {
        kx = M_PI_F * (2 * mPrime + 1 - N) / L;
    }

    if ((nPrime & 1) == 1) {
        kz = M_PI_F * (2 * nPrime + 1 - N) / L;
    }

    float2 k = float2(kx, kz);

    float omegat = sqrt(g * length(k)) * t;
    
    // Using euler's formula, e^ix == cos(x) + i * sin(x)   ...
    float2 exponent = float2(cos(omegat), sin(omegat));
    
    float2 v = ComplexMultiply(h0k.rg, exponent) + ComplexMultiply(float2(h0k.b, -h0k.a), float2(exponent.x, -exponent.y));

//    float v2 = 2 * M_PI_F * m * tpig.x / N;
//    float v2 = 2 * M_PI_F * m * tpig.x / N;
//    v = ComplexMultiply(v, float2(cos(v2), sin(v2)));

    output.write(float4(v.x, v.y, 0, 1), ushort2(tpig.x, tpig.y));
}

float2 h(
         float2 k,
         float t,
         const device Params &params,
         float2 noise1,
         float2 noise2
         )
{
    float g = 9.8; // meters per second^2
    
    float kLength = length(k);
    
    float2 h0k1 = float2(0, 0);
    float2 h0k2 = float2(0, 0);
    
    if (kLength != 0) {
        float L2 = (params.windSpeed * params.windSpeed) / g; // (m^2 / s) * (s^2 / m) --> meter seconds

        float kdotw = dot(normalize(k), params.windDirection);
        
        float damping = params.l;
        
        float phk = (params.A
            * exp(-1 / (kLength * kLength * L2 * L2))
            / pow(kLength, 4))
            * pow(kdotw, 8)
            * exp(-kLength * kLength * damping * damping);
        
        h0k1 = sqrt(phk / 2.0) * noise1;
        
        kdotw = dot(normalize(k), -params.windDirection);
        
        phk = (params.A
            * exp(-1 / (kLength * kLength * L2 * L2))
            / pow(kLength, 4))
            * pow(kdotw, params.windDirectionalFactor)
            * exp(-kLength * kLength * damping * damping);
        
        h0k2 = sqrt(phk / 2.0) * noise2;
    }

    float omegat = sqrt(g * kLength) * t;
    
    // Using euler's formula, e^ix == cos(x) + i * sin(x)   ...
    float2 exponent = float2(cos(omegat), sin(omegat));
    
    float2 v = ComplexMultiply(h0k1, exponent) + ComplexMultiply(float2(h0k2.x, -h0k2.y), float2(exponent.x, -exponent.y));

    return v;
}


kernel void naiveHeightCompute(
                                const device Params &params [[ buffer(0) ]],
                                const device float &t [[ buffer(1) ]],
                                texture2d<float, access::read> noise1 [[ texture(0) ]],
                                texture2d<float, access::read> noise2 [[ texture(1) ]],
                                texture2d<float, access::read> noise3 [[ texture(2) ]],
                                texture2d<float, access::read> noise4 [[ texture(3) ]],
                                texture2d<float, access::write> output [[ texture(4) ]],
                                uint2 tpig [[ thread_position_in_grid ]]
                                )
{
    int N = output.get_width();
     
    float2 height = float2(0, 0);
     
    int x = (int(tpig.x) - N / 2); // * params.L / N;
    int z = (int(tpig.y) - N / 2); // * params.L / N;
     
    for (int n = -(N / 2); n < (N / 2); ++n) {
        for (int m = -(N / 2); m < (N / 2); ++m) {
            float n1 = noise1.read(uint2(m + (N/2), n + (N/2))).r;
            float n2 = noise2.read(uint2(m + (N/2), n + (N/2))).r;
            float n3 = noise3.read(uint2(m + (N/2), n + (N/2))).r;
            float n4 = noise4.read(uint2(m + (N/2), n + (N/2))).r;
             
            float2 ns1 = float2(n1, n2);
            float2 ns2 = float2(n3, n4);
             
            float2 k = float2((M_PI_F * 2 * m) / params.L, (M_PI_F * 2 * n) / params.L);
             
            float2 v = h(k, t, params, ns1, ns2);
             
            float theta = (k.x * x * params.L) / N;
            v = ComplexMultiply(v, float2(cos(theta), sin(theta)));
            
            theta = (k.y * z * params.L) / N;
            v = ComplexMultiply(v, float2(cos(theta), sin(theta)));
             
            height += v;
        }
    }
     
    output.write(float4(height.x, height.y, 0, 1), tpig);
}
