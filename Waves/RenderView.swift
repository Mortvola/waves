//
//  RenderView.swift
//  Waves
//
//  Created by Richard Shields on 4/28/23.
//

import SwiftUI


struct RenderView: UIViewControllerRepresentable {
    typealias UIViewControllerType = RenderViewController
    
    func makeUIViewController(context: Context) -> RenderViewController {
        let viewController = RenderViewController()
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: RenderViewController, context: Context) {
    }
}
