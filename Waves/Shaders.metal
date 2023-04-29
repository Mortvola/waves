//
//  Shaders.metal
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[ position ]];
    float2 texcoord;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    
    out.position = float4(in.position.x / 512.0, in.position.y / 512.0, 0, 1);
    out.texcoord = in.texcoord;

    return out;
}

fragment float4 fragmentShader(
                               VertexOut in [[ stage_in ]],
                               texture2d<float> tex [[texture(0)]],
                               sampler sampler [[sampler(0)]])
{
    float4 out;
    
    out = tex.sample(sampler, in.texcoord);
    
    return out;
}

kernel void test(
                 texture2d<float, access::read> noise1 [[texture(0)]],
                 texture2d<float, access::read> noise2 [[texture(1)]],
                 texture2d<float, access::write> output [[texture(2)]],
                 uint2 tpig [[thread_position_in_grid]]
                 )
{
    float A = 20;
    float L = 1000;
    float N = output.get_height();
    
    // Wind speed
    float V = 5; // meters per second
    float2 w = normalize(float2(1, 1));

    float g = 9.8; // meters per second^2
    float L2 = (V * V) / g; // (m^2 / s) * (s^2 / m) --> meter seconds
    
    float l = 0.25;
    
    float n = tpig.x - N / 2;
    float m = tpig.y - N / 2;
                     
    float2 k = float2((2.0 * M_PI_F * n) / L, (2.0 * M_PI_F * m) / L);
    
    float kLength = length(k);
    float kdotw = dot(normalize(k), w);
    float negKdotw = dot(normalize(-k), w);
    
    if (kLength == 0) {
        kLength = 0.00001;
        kdotw = 0;
        negKdotw = 0;
    }
    
    float h0k = sqrt(
        (A / pow(kLength, 4))
        * exp(-1 / (kLength * kLength * L2 * L2))
        * pow(kdotw, 2)
        * exp(-kLength * kLength * l * l)
    ) / sqrt(2.0);
                     
    float n1 = noise1.read(ushort2(tpig.x, tpig.y)).r;
    float n2 = noise1.read(ushort2(tpig.x, tpig.y)).r;

    output.write(float4(h0k * n1, h0k * n2, 0, 1), ushort2(tpig.x, tpig.y));
}
