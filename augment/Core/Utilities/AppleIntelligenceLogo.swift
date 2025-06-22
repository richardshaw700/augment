import Foundation
import AppKit

struct AppleIntelligenceLogo {
    static var nsImage: NSImage? {
        // Use PNG resource for better rendering compatibility
        guard let imageURL = Bundle.main.url(forResource: "apple-intelligence-logo", withExtension: "png", subdirectory: "Resources/Pngs") else {
            print("❌ Could not find apple-intelligence-logo.png in Resources/Pngs")
            return nil
        }
        
        guard let image = NSImage(contentsOf: imageURL) else {
            print("❌ Failed to create NSImage from apple-intelligence-logo.png")
            return nil
        }
        
        print("✅ Successfully loaded Apple Intelligence logo from PNG")
        return image
    }
} 