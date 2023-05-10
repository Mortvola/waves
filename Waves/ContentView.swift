//
//  ContentView.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var settings = Settings.shared
    @State var paused = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State var time: Double = 0
    
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
                    Checkbox(checked: $settings.xzDisplacement, label: "XZ Displacement")
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
                    } onDecrement: {
                        settings.windDirection -= 1
                        if settings.windDirection == -1 {
                            settings.windDirection = 359
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
                        Text("L: \(settings.L)")
                    } onIncrement: {
                        settings.L += 1
                    } onDecrement: {
                        if settings.L > 1 {
                            settings.L -= 1
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
                        Text("Time: \(String(format: "%.3f", time))")
                            .onReceive(timer) { _ in
                                time = clock.getTime()
                            }
                    } onIncrement: {
                        clock.stepForward()
                    } onDecrement: {
                        clock.stepBackward()
                    }
                        .foregroundColor(.white)
                        .accentColor(.white)
                        .padding(.leading)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                HStack {
                    Button {
                        paused.toggle()
                        
                        if paused {
                            clock.pause()
                            time = clock.getTime()
                        }
                        else {
                            clock.resume()
                        }
                    } label: {
                        Text(paused ? "Resume" : "Pause")
                    }
                    .padding()
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
