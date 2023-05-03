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
                        Text("Wind Speed: \(String(format: "%.0f", settings.windDirection))")
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
