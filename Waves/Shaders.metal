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
    uint id;
};

vertex VertexOut vertexShader(
                              VertexIn in [[ stage_in ]]
                              )
{
    VertexOut out;
    
    out.position = float4(in.position.x / 512.0, in.position.y / 512.0, 0, 1);
    out.texcoord = in.texcoord;

    return out;
}

fragment float4 fragmentShader(
                               VertexOut in [[ stage_in ]],
                               texture2d<float> tex [[ texture(0) ]],
                               sampler sampler [[ sampler(0) ]]
                               )
{
    float4 out;
    
    out = tex.sample(sampler, in.texcoord);
    
    return out;
}

vertex VertexOut vertexWaveShader(
                                  VertexIn in [[ stage_in ]],
                                  const device FrameConstants& frameConstants [[ buffer(BufferIndexFrameConstants) ]],
                                  uint vertexId [[ vertex_id ]],
                                  texture2d<float, access::read> height [[ texture(3) ]]
                                  )
{
    VertexOut out;
    
    int x = vertexId % height.get_width();
    int y = vertexId / height.get_width();
    
    float4 h = height.read(uint2(x, y));
    
    out.position = frameConstants.projectionMatrix * frameConstants.viewMatrix * float4(in.position.x, in.position.y + h.x, in.position.z, 1.0);
    out.texcoord = in.texcoord;
//    out.id = id;

    return out;
}

fragment float4 fragmentWaterShader(
                                    VertexOut in [[ stage_in ]]
                                    )
{
    return float4(1, 0, 0, 1);
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
    
    float m = tpig.x; // - N / 2;
    float n = tpig.y; // - N / 2;
                     
    float2 k = float2(M_PI_F * (2 * m - N) / L, M_PI_F * (2 * n - N) / L);
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
            * exp(-kLength * kLength * L2 * L2 * damping * damping);
        
        h0k1 = sqrt(phk / 2.0) * noise1;
        
        kdotw = dot(normalize(k), -params.windDirection);
        
        phk = (A
            * exp(-1 / (kLength * kLength * L2 * L2))
            / pow(kLength, 4))
            * pow(kdotw, 2)
            * exp(-kLength * kLength * L2 * L2 * damping * damping);
        
        h0k2 = sqrt(phk) * noise2 / sqrt(2.0);
    }
    
    output.write(float4(h0k1.x, h0k1.y, h0k2.x, h0k2.y), ushort2(tpig.x, tpig.y));
}

kernel void makeTimeTexture(
                            const device float &t [[ buffer(0) ]],
                            texture2d<float, access::read> input [[ texture(0) ]],
                            texture2d<float, access::write> output [[ texture(1) ]],
                            uint2 tpig [[ thread_position_in_grid ]]
                           )
{
    float4 h0k = input.read(ushort2(tpig.x, tpig.y));
    
    float L = 1000;
    float N = input.get_width();

    float n = tpig.x - N / 2;
    float m = tpig.y - N / 2;

    float g = 9.8; // meters per second^2
    float2 k = float2((2.0 * M_PI_F * n) / L, (2.0 * M_PI_F * m) / L);

    float w = sqrt(g * length(k));
    
    // Using euler's formula, e^ix == cos(x) + i * sin(x)...
    float2 exponent = float2(cos(w * t), sin(w * t));
    
    float2 v = ComplexMultiply(h0k.rg, exponent) + ComplexMultiply(h0k.ba, float2(exponent.x, -exponent.y));
    
    output.write(float4(v.x, v.y, 0, 1), ushort2(tpig.x, tpig.y));
}

kernel void naiveHeightCompute(
                               const device Params &params [[ buffer(0) ]],
                               const device float &t [[ buffer(1) ]],
                               texture2d<float, access::read> hk0texture [[ texture(3) ]],
                               texture2d<float, access::write> output [[ texture(4) ]],
                               uint2 tpig [[ thread_position_in_grid ]]
                               )
{
    float N = output.get_width();
    int L = params.L;
    float g = 9.8; // meters per second^2
    
    float2 height = float2(0, 0);

    for (int n = 0; n < N; ++n) {
        
        float2 innerHeight = float2(0, 0);
        
        float kz = M_PI_F * (2 * n - N) / L;
        
        for (int m = 0; m < N; ++m) {

            float kx = M_PI_F * (2 * m - N) / L;
            
            float2 k = float2(kx, kz);
            float kLength = length(k);

            float4 h0k = hk0texture.read(ushort2(m, n)).r;

            float omegat = sqrt(g * kLength) * t;
            
            // Using euler's formula, e^ix == cos(x) + i * sin(x)...
            float2 exponent = float2(cos(omegat), sin(omegat));
                        
            float2 v = ComplexMultiply(h0k.rg, exponent) + ComplexMultiply(float2(h0k.b, -h0k.a), float2(exponent.x, -exponent.y));

            float v2 = 2 * M_PI_F * m * tpig.x / N;
            
            v = ComplexMultiply(v, float2(cos(v2), sin(v2)));
            
            innerHeight += v;
        }
        
        float v4 = 2 * M_PI_F * n * tpig.y / N;

        float2 v3 = ComplexMultiply(innerHeight, float2(cos(v4), sin(v4)));
        
        height += v3;
    }
    
    height = ComplexMultiply(height, float2(cos(-M_PI_F * tpig.y), sin(-M_PI_F * tpig.y)));
    height = ComplexMultiply(height, float2(cos(-M_PI_F * tpig.x), sin(-M_PI_F * tpig.x)));

    output.write(float4(height.x, height.y, 0, 1), ushort2(tpig.x, tpig.y));
}
