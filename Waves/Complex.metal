//
//  Complex.metal
//  Waves
//
//  Created by Richard Shields on 5/2/23.
//

#include <metal_stdlib>
#include "Complex.h"

using namespace metal;


float2 ComplexMultiply(float2 a, float2 b)
{
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

