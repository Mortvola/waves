//
//  Clock.swift
//  Waves
//
//  Created by Richard Shields on 5/10/23.
//

import Foundation

class Clock {
    private var previousFrameTime: Double?

    private var fixedFrameTime: Double? = nil
    
    func getTime() -> Double {
        return ProcessInfo.processInfo.systemUptime
    }

    func getElapsedTime() -> Double? {
        if let fixedFrameTime = self.fixedFrameTime {
            return fixedFrameTime
        }
        
        let now = getTime()

        defer {
            previousFrameTime = now
        }
        
        if let previousFrameTime = previousFrameTime {
            let elapsedTime = now - previousFrameTime
            
            return elapsedTime
        }
        
        return nil
    }
}
