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
    
    private var butterflyTexture: MTLTexture
    private var inverseButterflyTexture: MTLTexture

    private var horzFFTPipeline: MTLComputePipelineState? = nil
    
    private var inverseHorzFFTPipeline: MTLComputePipelineState? = nil
    private var inverseVertFFTPipeline: MTLComputePipelineState? = nil

    private var inverseFFTDividePipeline: MTLComputePipelineState? = nil
    
    init(M: Int, N: Int, commandQueue: MTLCommandQueue) throws {
        self.M = M
        self.N = N

        butterflyTexture = try makeButterflyTexture(N: N, inverse: false, commandQueue: commandQueue)
        inverseButterflyTexture = try makeButterflyTexture(N: N, inverse: true, commandQueue: commandQueue)
        
        try makeFFTPipelines()
        
        test();
        test2();
    }
    
    func makeFFTPipelines() throws {
        let library = MetalView.shared.device.makeDefaultLibrary()

        guard let horzFunction = library?.makeFunction(name: "horzFFTStage") else {
            return
        }

        horzFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: horzFunction)

        guard let inverseHorzFunction = library?.makeFunction(name: "inverseHorzFFTStage") else {
            return
        }
        
        inverseHorzFFTPipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseHorzFunction)

        guard let vertFunction = library?.makeFunction(name: "inverseVertFFTStage") else {
            return
        }

        inverseVertFFTPipeline = try? MetalView.shared.device.makeComputePipelineState(function: vertFunction)

        guard let inverseFFTDivide = library?.makeFunction(name: "inverseFFTDivide") else {
            return
        }
        
        inverseFFTDividePipeline = try MetalView.shared.device.makeComputePipelineState(function: inverseFFTDivide)
    }
    

    func FFT() {
        
    }
    
    func horizontalFFT(computeEncoder: MTLComputeCommandEncoder, data: [MTLTexture], startingBuffer: Int) -> Int {
        // Perform horizontal FFT
        computeEncoder.setComputePipelineState(horzFFTPipeline!)
        
        computeEncoder.setTexture(butterflyTexture, index: 2)
        
        let stages = Int(log2(Float(M)))
        
        let threadsPerGrid = MTLSizeMake(M, N, 1)

        let width = horzFFTPipeline!.threadExecutionWidth
        let height = horzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = startingBuffer
        
        for stage in 0..<stages {
            computeEncoder.setTexture(data[pingpong], index: 0)
            computeEncoder.setTexture(data[pingpong ^ 1], index: 1)
            
            var s: Int = stage
            computeEncoder.setBytes(&s, length: MemoryLayout<Int>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
        
        return pingpong;
    }
    
    func inverseHorizontalFFT(computeEncoder: MTLComputeCommandEncoder, data: [MTLTexture], startingBuffer: Int) -> Int {
        // Perform horizontal inverse FFT
        computeEncoder.setComputePipelineState(inverseHorzFFTPipeline!)
        
        computeEncoder.setTexture(inverseButterflyTexture, index: 2)
        
        let stages = Int(log2(Float(M)))

        let threadsPerGrid = MTLSizeMake(M, N, 1)

        let width = inverseHorzFFTPipeline!.threadExecutionWidth
        let height = inverseHorzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = startingBuffer

        for stage in 0..<stages {
            computeEncoder.setTexture(data[pingpong], index: 0)
            computeEncoder.setTexture(data[pingpong ^ 1], index: 1)
            
            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))
            
            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }
        
//        inverseFFTDivide(computeEncoder: computeEncoder, data: data[pingpong])
        
        return pingpong
    }
    
    func inverseVerticalFFT(computeEncoder: MTLComputeCommandEncoder, data: [MTLTexture], startingBuffer: Int) -> Int {
        computeEncoder.setComputePipelineState(inverseVertFFTPipeline!)

        computeEncoder.setTexture(inverseButterflyTexture, index: 2)

        let stages = Int(log2(Float(M)))

        let threadsPerGrid = MTLSizeMake(M, N, 1)

        let width = inverseHorzFFTPipeline!.threadExecutionWidth
        let height = inverseHorzFFTPipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var pingpong = startingBuffer

        for stage in 0..<stages {
            computeEncoder.setTexture(data[pingpong], index: 0)
            computeEncoder.setTexture(data[pingpong ^ 1], index: 1)

            var s: InverseFFTParams = InverseFFTParams(stage: Int32(stage), lastStage: Int32(stages - 1))

            computeEncoder.setBytes(&s, length: MemoryLayout<InverseFFTParams>.size, index: 0)
            computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            
            pingpong ^= 1
        }

        inverseFFTDivide(computeEncoder: computeEncoder, data: data[pingpong])
        
        return pingpong
    }
    
    func inverseFFTDivide(computeEncoder: MTLComputeCommandEncoder, data: MTLTexture) {
        computeEncoder.setComputePipelineState(inverseFFTDividePipeline!)

        let threadsPerGrid = MTLSizeMake(M, N, 1)
        
        let width = inverseFFTDividePipeline!.threadExecutionWidth
        let height = inverseFFTDividePipeline!.maxTotalThreadsPerThreadgroup / width
        
        let threadsPerGroup = MTLSizeMake(width, height, 1)

        var multiplier = 1.0 / Float(N)

        computeEncoder.setBytes(&multiplier, length: MemoryLayout<Float>.size, index: 0)
        computeEncoder.setTexture(data, index: 0)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
    }
    
//    struct Params {
//        var N: Int
//        var L: Int
//        var windSpeed: Float
//        var windDirection: simd_float2
//        var l: Float
//        var A: Float
//    }
    
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
    
    func test() {
        let M = 8;
        let N = 1
        let params = Settings.shared
             
        let t: Float = 0;
        
        var height: [simd_float2] = []
        
        for _ in 0..<M {
            height.append(simd_float2(0, 0))
        }
        
        let z1 = 0
        let z: Int = (z1 - N/2) * Int(params.L) / N;
        let n = -N/2;
        
        for x1 in 0..<M {
            let x: Int = (x1 - M/2) * Int(params.L) / M;
             
            for m in -Int(M / 2)..<Int(M / 2) {
                let k = simd_float2((Float.pi * 2 * Float(m)) / Float(params.L), (Float.pi * 2 * Float(n)) / Float(params.L));
                 
                var v = h(k, t, params);
                
                print(v);
                 
                let theta = (Float.pi * 2 * Float(m + M/2) * Float(x1)) / Float(M);
                v = ComplexMultiply(v, simd_float2(cos(theta), sin(theta)));
//                v = ComplexMultiply(v, simd_float2(cos(k.x * Float(x)), sin(k.x * Float(x))));
//                v = ComplexMultiply(v, simd_float2(cos(k.y * Float(z)), sin(k.y * Float(z))));
                
                print(v);
                 
                height[x1] += v;
            }
        }
        
        for x in 0..<M {
            if ((x & 1) == 1) {
                height[x] = -height[x]
            }
        }

        print(height);
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

    func test2() {
        let M = 8;
        let N = 1;
        let params = Settings.shared
        let t: Float = 0
        
        var height: [[simd_float2]] = [[], []]
        
        for _ in 0..<M {
            height[0].append(simd_float2(0, 0))
            height[1].append(simd_float2(0, 0))
        }
        var pingpong = 0

        let stages = Int(log2(Float(M)))
        
        for stage in 0..<stages {
            for x1 in 0..<M {
                let lanesPerGroup: Int = Int(powf(2, Float(stage + 1)));
                
                var sign: Int = 1;
                
                var v1 = simd_float2(0, 0)
                var v2 = simd_float2(0, 0)
                
                if (stage == 0) {
                    let length = log2(Float(M));
                    let index1 = Int(reverseBits(UInt((x1 / 2) * 2), UInt(length)));
                    let index2 = Int(reverseBits(UInt((x1 / 2) * 2 + 1), UInt(length)));

                    if ((x1 & 1) == 1) {
                        sign = -1;
                    }
                    
                    var m = index1 - M/2;
                    let n = 0 - N/2;
                    
                    var k = simd_float2((Float.pi * 2 * Float(m)) / Float(params.L), (Float.pi * 2 * Float(n)) / Float(params.L));
                    v1 = h(k, t, params);
                    
                    m = index2 - M/2;
                    
                    k = simd_float2((Float.pi * 2 * Float(m)) / Float(params.L), (Float.pi * 2 * Float(n)) / Float(params.L));
                    v2 = h(k, t, params);
                }
                else {
                    let index1: Int = x1 % (lanesPerGroup / 2) + (x1 / lanesPerGroup) * lanesPerGroup;
                    let index2: Int = index1 + (lanesPerGroup / 2);

                    if (index2 == x1) {
                        sign = -1;
                    }
                    
                    v1 = height[pingpong][index1]
                    v2 = height[pingpong][index2]
                }
                
                let groupButterflyIndex: Int = x1 % (lanesPerGroup / 2);
                
                let theta: Float = (2.0 * Float.pi * Float(groupButterflyIndex)) / Float(lanesPerGroup);
                
                // de Moivre's formula: (cos(theta) + i sin(theta))^n = cos(n * theta) + i sin(n * theta)
                var w = simd_float2(cos(theta), sin(theta));
                w *= Float(sign);
                
//                print("w = \(w), v1 = \(v1), v2 = \(v2)")
                height[pingpong ^ 1][x1] = v1 + ComplexMultiply(v2, w);
            }
            
            pingpong ^= 1
            
//            print(height[pingpong])
        }

        for x in 0..<M {
            if ((x & 1) == 1) {
                height[pingpong][x] = -height[pingpong][x]
            }
        }

        print(height[pingpong])
    }
}

func ComplexMultiply(_ a: simd_float2 , _ b: simd_float2) -> simd_float2
{
    return simd_float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}
