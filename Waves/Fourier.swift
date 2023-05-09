//
//  Fourier.swift
//  Waves
//
//  Created by Richard Shields on 5/3/23.
//

import Foundation
import Metal

class Fourier {
    private var M: Int
    private var N: Int
    
    init(M: Int, N: Int, commandQueue: MTLCommandQueue) throws {
        self.M = M
        self.N = N

        let N = 16
        let t1 = test(N);
        let t2 = test3(N);

        for z in 0..<N {
            for x in 0..<N {
                if abs(t1[z][x].x - t2[z][x].x) > 0.001 || abs(t1[z][x].y - t2[z][x].y) > 0.001 {
                    print(t1[z][x] - t2[z][x])
                }
            }
        }

        let t3 = test2(N);

        for z in 0..<N {
            for x in 0..<N {
                if abs(t1[z][x].x - t3[z][x].x) > 0.001 || abs(t1[z][x].y - t3[z][x].y) > 0.001 {
                    print(t1[z][x] - t3[z][x])
                }
            }
        }
    }

    func h(_ k: simd_float2, _ t: Float, _ params: Settings) -> simd_float2 {
        let g: Float = 9.8; // meters per second^2
        
        let kLength: Float = length(k);
        
        var h0k1 = simd_float2(0, 0);
        var h0k2 = simd_float2(0, 0);
        
        if (kLength != 0) {
            let n1 = Float(0.25)
            let n2 = Float(0.5)
            let n3 = Float(0.75)
            let n4 = Float(1.0)
             
            let noise1 = simd_float2(n1, n2);
            let noise2 = simd_float2(n3, n4);
             
            let L2: Float = (params.windspeed * params.windspeed) / g; // (m^2 / s) * (s^2 / m) --> meter seconds

            let wd = simd_float2(cos(Settings.shared.windDirection / 180 * Float.pi), sin(Settings.shared.windDirection / 360 * Float.pi))
            var kdotw: Float = dot(normalize(k), wd);
            
            let damping: Float = params.l;
            
            var phk: Float = (params.A
                * exp(-1 / (kLength * kLength * L2 * L2))
                / pow(kLength, 4))
                * pow(kdotw, 2)
                * exp(-kLength * kLength * damping * damping);
            
            h0k1 = sqrt(phk / 2.0) * noise1;
            
            kdotw = dot(normalize(k), -wd);
            
            phk = (params.A
                * exp(-1 / (kLength * kLength * L2 * L2))
                / pow(kLength, 4))
                * pow(kdotw, 2)
                * exp(-kLength * kLength * damping * damping);
            
            h0k2 = sqrt(phk / 2.0) * noise2;
        }

        let omegat: Float = sqrt(g * kLength) * t;
        
        // Using euler's formula, e^ix == cos(x) + i * sin(x)   ...
        let exponent = simd_float2(cos(omegat), sin(omegat));
        
        let v = ComplexMultiply(h0k1, exponent) + ComplexMultiply(simd_float2(h0k2.x, -h0k2.y), simd_float2(exponent.x, -exponent.y));

        return v;
    }
    
    func test(_ M: Int) -> [[simd_float2]] {
        let params = Settings.shared
             
        let t: Float = 0;
        
        var height: [[simd_float2]] = []
        
        for z in 0..<M {
            height.append([])
            
            for _ in 0..<M {
                height[z].append(simd_float2(0, 0))
            }
        }
        
        for y in -Int(M/2)..<Int(M/2) {
            for x in -Int(M/2)..<Int(M/2) {
                for n in -Int(M / 2)..<Int(M / 2) {
                    for m in -Int(M / 2)..<Int(M / 2) {
                        let k = simd_float2((Float.pi * 2 * Float(m)) / Float(params.L), (Float.pi * 2 * Float(n)) / Float(params.L));
                        
                        var v = h(k, t, params);
                        
                        var theta = (Float.pi * 2 * Float(m) * Float(x)) / Float(M);
                        v = ComplexMultiply(v, simd_float2(cos(theta), sin(theta)));
                        
                        theta = (Float.pi * 2 * Float(n) * Float(y)) / Float(M);
                        v = ComplexMultiply(v, simd_float2(cos(theta), sin(theta)));
                        
                        height[y + M/2][x + M/2] += v;
                    }
                }
            }
        }
        
//        for x in 0..<M {
//            if ((x & 1) == 1) {
//                height[x] = -height[x]
//            }
//        }

//        for z in 0..<M {
//            for x in 0..<M {
//                print("(\(height[z][x].x), \(height[z][x].y))");
//            }
//        }
        
        return height
    }

    func test3(_ N: Int) -> [[simd_float2]] {
        let params = Settings.shared
             
        let t: Float = 0;
        
        var height: [[simd_float2]] = []
        
        for z in 0..<N {
            height.append([])
            
            for _ in 0..<N {
                height[z].append(simd_float2(0, 0))
            }
        }
        
        for zPrime in 0..<N {
            for xPrime in 0..<N {
                for nPrime in 0..<N {
                    
                    var innerHeight = simd_float2(0, 0)
                    
                    for mPrime in 0..<N {
                        let k = simd_float2((Float.pi * 2 * Float(mPrime - N/2)) / Float(params.L), (Float.pi * 2 * Float(nPrime - N/2)) / Float(params.L));
                        
                        var v = h(k, t, params);
                        
                        var theta = (Float.pi * 2 * Float(mPrime) * Float(xPrime)) / Float(N)
                        v = ComplexMultiply(v, simd_float2(cos(theta), sin(theta)));
                        
                        v *= powf(-1, Float(mPrime))
                        
                        theta = (Float.pi * 2 * Float(nPrime) * Float(zPrime)) / Float(N)
                        v = ComplexMultiply(v, simd_float2(cos(theta), sin(theta)));

                        v *= powf(-1, Float(nPrime))

                        innerHeight += v;
                    }

                    height[zPrime][xPrime] += innerHeight;
                }
            }
        }
        
        for z in -Int(N/2)..<Int(N/2) {
            for x in -Int(N/2)..<Int(N/2) {
                if (((x & 1) ^ (z & 1)) == 1) {
                    height[z + N/2][x + N/2] = -height[z + N/2][x + N/2]
                }
            }
        }

//        print("-------")
//        for z in 0..<N {
//            for x in 0..<N {
//                print("(\(height[z][x].x), \(height[z][x].y))");
//            }
//        }
        
        return height
    }

    func reverseBits(_ n: UInt, _ length: UInt) -> UInt {
        var r: UInt = 0;
        var n1 = n;
        
        for _ in 0..<length {
            r <<= 1;
            if ((n1 & 1) == 1) {
                r ^= 1;
            }
            
            n1 >>= 1;
        }
        
        return r;
    }

    func testMakeTimeTexture(_ N: Int, _ height: inout [[simd_float2]]) {
        let params = Settings.shared
        let t: Float = 0

        for nPrime in 0..<N {
            for mPrime in 0..<N {
                let k = simd_float2((Float.pi * 2 * Float(mPrime - N/2)) / Float(params.L), (Float.pi * 2 * Float(nPrime - N/2)) / Float(params.L));
                var v = h(k, t, params);
                
                if (((mPrime & 1) ^ (nPrime & 1)) == 1) {
                    v = -v;
                }
                
                height[nPrime][mPrime] = v;
            }
        }

        print("Initial --------")
        for z in 0..<N {
            for x in 0..<N {
                print("(\(height[z][x].x), \(height[z][x].y))");
            }
        }
    }
        
    func testHorizontalFFTStage(_ stage: Int, _ N: Int, _ input: [[simd_float2]], _ output: inout [[simd_float2]]) {
        for z in 0..<N {
            for x in 0..<N {
                let lanesPerGroup: Int = Int(powf(2, Float(stage + 1)));

                var sign: Int = 1;
                
                var index1 = 0;
                var index2 = 0;
                
                if (stage == 0) {
                    let length = log2(Float(N));
                    index1 = Int(reverseBits(UInt((x / 2) * 2), UInt(length)));
                    index2 = Int(reverseBits(UInt((x / 2) * 2 + 1), UInt(length)));

                    if ((x & 1) == 1) {
                        sign = -1;
                    }
                }
                else {
                    index1 = x % (lanesPerGroup / 2) + (x / lanesPerGroup) * lanesPerGroup;
                    index2 = index1 + (lanesPerGroup / 2);

                    if (index2 == x) {
                        sign = -1;
                    }
                }
                
                let v1 = input[z][index1]
                let v2 = input[z][index2]

                let groupButterflyIndex: Int = x % (lanesPerGroup / 2);
                
                let theta: Float = (2.0 * Float.pi * Float(groupButterflyIndex)) / Float(lanesPerGroup);
                
                // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
                var w = simd_float2(cos(theta), sin(theta));
                w *= Float(sign);
                
                output[z][x] = v1 + ComplexMultiply(v2, w);
            }
        }
    }

    func testVerticalFFTStage(_ stage: Int, _ N: Int, _ input: [[simd_float2]], _ output: inout [[simd_float2]]) {
        for z in 0..<N {
            for x in 0..<N {
                let lanesPerGroup: Int = Int(powf(2, Float(stage + 1)));

                var sign: Int = 1;
                
                var index1 = 0;
                var index2 = 0;
                
                if (stage == 0) {
                    let length = log2(Float(N));
                    index1 = Int(reverseBits(UInt((z / 2) * 2), UInt(length)));
                    index2 = Int(reverseBits(UInt((z / 2) * 2 + 1), UInt(length)));

                    if ((z & 1) == 1) {
                        sign = -1;
                    }
                }
                else {
                    index1 = z % (lanesPerGroup / 2) + (z / lanesPerGroup) * lanesPerGroup;
                    index2 = index1 + (lanesPerGroup / 2);

                    if (index2 == z) {
                        sign = -1;
                    }
                }
                
                let v1 = input[index1][x]
                let v2 = input[index2][x]

                let groupButterflyIndex: Int = z % (lanesPerGroup / 2);
                
                let theta: Float = (2.0 * Float.pi * Float(groupButterflyIndex)) / Float(lanesPerGroup);
                
                // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
                var w = simd_float2(cos(theta), sin(theta));
                w *= Float(sign);
                
                output[z][x] = v1 + ComplexMultiply(v2, w);
            }
        }
    }

    func test2(_ N: Int) -> [[simd_float2]] {
        var height: [[[simd_float2]]] = []
        var pingpong = 0
        
        for p in 0..<2 {
            height.append([])
            for n in 0..<N {
                height[p].append([])
                for _ in 0..<N {
                    height[p][n].append(simd_float2(0, 0))
                }
            }
        }
        
        testMakeTimeTexture(N, &height[0])
        
        let stages = Int(log2(Float(N)))
        
        for stage in 0..<stages {
            testHorizontalFFTStage(stage, N, height[pingpong], &height[pingpong ^ 1])
            pingpong ^= 1
        }
        
        for stage in 0..<stages {
            testVerticalFFTStage(stage, N, height[pingpong], &height[pingpong ^ 1])
            pingpong ^= 1
        }
        
        for z in 0..<N {
            for x in 0..<N {
                if (((x & 1) ^ (z & 1)) == 1) {
                    height[pingpong][z][x] = -height[pingpong][z][x]
                }
            }
        }

        print("--------")
        for z in 0..<N {
            for x in 0..<N {
                print("(\(height[pingpong][z][x].x), \(height[pingpong][z][x].y))");
            }
        }
        
        return height[pingpong]
    }
}

func ComplexMultiply(_ a: simd_float2 , _ b: simd_float2) -> simd_float2
{
    return simd_float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}
