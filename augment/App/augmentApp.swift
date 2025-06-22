//
//  augmentApp.swift
//  augment
//
//  Created by Richard Shaw on 2025-06-19.
//

import SwiftUI

@main
struct augmentApp: App {
    @StateObject private var notchViewModel = NotchViewModel()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        
        // Menu bar integration for notch interface
        MenuBarExtra("Augment", systemImage: "wand.and.stars") {
            VStack {
                Button("Show Notch Interface") {
                    // The notch interface is always running, this is just a fallback
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
