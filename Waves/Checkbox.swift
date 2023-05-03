//
//  Checkbox.swift
//  Waves
//
//  Created by Richard Shields on 5/3/23.
//

import SwiftUI

struct Checkbox: View {
    @Binding var checked: Bool
    var label: String
    
    var body: some View {
        HStack {
            Image(systemName: checked ? "checkmark.square.fill" : "square")
                .foregroundColor(checked ? Color(.systemBlue) : Color.secondary)
                .onTapGesture {
                    self.checked.toggle()
                }
            Text(label)
        }
    }
}

struct Checkbox_Previews: PreviewProvider {
    static var previews: some View {
        Checkbox(checked: .constant(true), label: "Test")
    }
}
