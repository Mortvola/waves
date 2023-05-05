//
//  ContentView.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var settings = Settings.shared
    
    var body: some View {
        ZStack {
            RenderView()
            VStack {
                HStack {
                    Checkbox(checked: $settings.wireframe, label: "Wireframe")
                        .foregroundColor(.white)
                        .padding([.leading, .top])
                    Spacer()
                }
                HStack {
                    Stepper(value: $settings.windspeed, in: 0...50, step: 0.1) {
                        Text("Wind Speed: \(String(format: "%.1f", settings.windspeed))")
                    }
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .padding(.leading)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                HStack {
                    Stepper {
                        Text("Wind Direction: \(String(format: "%.0f", settings.windDirection))")
                    } onIncrement: {
                        settings.windDirection += 1
                        if settings.windDirection == 360 {
                            settings.windDirection = 0
                        }
                        settings.step = true
                    } onDecrement: {
                        settings.windDirection -= 1
                        if settings.windDirection == -1 {
                            settings.windDirection = 359
                        }
                        settings.step = true
                    }
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .padding(.leading)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                HStack {
                    Stepper {
                        Text("L: \(settings.L)")
                    } onIncrement: {
                        settings.L += 1
                        settings.step = true
                    } onDecrement: {
                        if settings.L > 1 {
                            settings.L -= 1
                            settings.step = true
                        }
                    }
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .padding(.leading)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                HStack {
                    Stepper {
                        Text("Time: \(String(format: "%.3f", settings.time))")
                    } onIncrement: {
                        settings.time += 0.033
                        settings.step = true
                    } onDecrement: {
                        if settings.time > 0 {
                            settings.time -= 0.033
                            settings.time = max(settings.time, 0)
                            settings.step = true
                        }
                    }
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .padding(.leading)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
