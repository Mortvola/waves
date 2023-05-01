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

kernel void makeButterflyTexture(
                                 texture2d<float, access::write> output [[texture(0)]],
                                 uint2 tpig [[thread_position_in_grid]]
                                 )
{
    int stage = tpig.y + 1;
    
    int lanesPerGroup = pow(2.0, stage);
    int index1 = tpig.x % (lanesPerGroup / 2) + (tpig.x / lanesPerGroup) * lanesPerGroup;
    int index2 = index1 + (lanesPerGroup / 2);
    int groupButterflyIndex = tpig.x % (lanesPerGroup / 2);
    
    float theta = -2 * M_PI_F / lanesPerGroup;
//    float theta = -2 * M_PI_F / output.get_width();
    
    // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
    float2 w = float2(cos(theta * groupButterflyIndex), sin(theta * groupButterflyIndex));
    w *= index2 == int(tpig.x) ? -1 : 1;
    
    output.write(float4(w.x, w.y, index1, index2), tpig);
}

struct Params {
    float2 windDirection;
};

kernel void makeInputTexture(
                 const device Params &params [[buffer(0)]],
                 texture2d<float, access::read> noise1 [[texture(0)]],
                 texture2d<float, access::read> noise2 [[texture(1)]],
                 texture2d<float, access::write> output [[texture(2)]],
                 uint2 tpig [[thread_position_in_grid]]
                 )
{
    float A = 20;
    float L = 1000;
    float N = output.get_width();
    
    // Wind speed
    float V = 5; // meters per second

    float g = 9.8; // meters per second^2
    float L2 = (V * V) / g; // (m^2 / s) * (s^2 / m) --> meter seconds
    
    float l = 0.25;
    
    float n = tpig.x - N / 2;
    float m = tpig.y - N / 2;
                     
    float2 k = float2((2.0 * M_PI_F * n) / L, (2.0 * M_PI_F * m) / L);
    
    float kLength = length(k);
    float kdotw = dot(normalize(k), params.windDirection);
    float negKdotw = dot(normalize(-k), params.windDirection);
    
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

float2 ComplexMultiply(float2 a, float2 b)
{
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

kernel void makeTimeTexture(
                            const device float &t [[buffer(0)]],
                            texture2d<float, access::read> input1 [[texture(0)]],
                            texture2d<float, access::read> input2 [[texture(1)]],
                            texture2d<float, access::read> butterfly [[texture(2)]],
                            texture2d<float, access::write> output [[texture(3)]],
                            uint2 tpig [[thread_position_in_grid]]
                           )
{
    float2 h0k = input1.read(ushort2(tpig.x, tpig.y)).rg;
    float2 negh0k = input2.read(ushort2(tpig.x, tpig.y)).rg;
    
    float L = 1000;
    float N = input1.get_width();

    float n = tpig.x - N / 2;
    float m = tpig.y - N / 2;

    float g = 9.8; // meters per second^2
    float2 k = float2((2.0 * M_PI_F * n) / L, (2.0 * M_PI_F * m) / L);

    float w = sqrt(g * length(k));
    
    // Usnig euler's formula, e^ix == cos(x) + i * sin(x)...
    float2 exponent = float2(cos(w * t), sin(w * t));
    
    float2 v = ComplexMultiply(h0k, exponent) + ComplexMultiply(negh0k, float2(exponent.x, -exponent.y));
    
    output.write(float4(v.x, v.y, 0, 1), ushort2(tpig.x, tpig.y));
}
