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
