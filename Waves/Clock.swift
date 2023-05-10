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
    
    private var time: Double?
    private var paused = false
    private var pausedTime: Double = 0.0
    private var timeOfPause: Double?
    
    func getTime() -> Double {
        if paused {
            return timeOfPause! - pausedTime
        }
        
        return ProcessInfo.processInfo.systemUptime - pausedTime
    }

    func getElapsedTime() -> Double? {
        if paused {
            return 0
        }
        
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
    
    func pause() {
        if !paused {
            paused = true
            timeOfPause = ProcessInfo.processInfo.systemUptime
        }
    }
    
    func resume() {
        if paused {
            pausedTime += ProcessInfo.processInfo.systemUptime - timeOfPause!
            paused = false
        }
    }
}
