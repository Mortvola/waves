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
    
    private var time: Double!
    private var baseTime: Double?
    private var paused = false
    private var pausedTime: Double = 0.0
    private var timeOfPause: Double?
    
    func getTime() -> Double {
        if !paused {
            if baseTime == nil {
                baseTime = ProcessInfo.processInfo.systemUptime
            }
            
            time = ProcessInfo.processInfo.systemUptime - pausedTime - baseTime!
        }
        
        return time
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
        }
    }
    
    func resume() {
        if paused {
            baseTime = ProcessInfo.processInfo.systemUptime - time
            paused = false
        }
    }
    
    func stepForward() {
        if paused {
            time += 33.0 / 1000.0
        }
    }
    
    func stepBackward() {
        if paused {
            time = max(time - 33.0 / 1000.0, 0)
        }
    }

}
