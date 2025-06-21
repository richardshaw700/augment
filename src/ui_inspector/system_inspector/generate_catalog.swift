#!/usr/bin/env swift

import Foundation
import AppKit

// Include the ApplicationCatalog class directly
class ApplicationCatalog {
    
    static func generateCatalog() -> [String: Any] {
        var catalog: [String: Any] = [:]
        var applications: [[String: Any]] = []
        
        let applicationsPath = "/Applications"
        let fileManager = FileManager.default
        
        print("🔍 Scanning Applications folder...")
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: applicationsPath)
            let appFiles = contents.filter { $0.hasSuffix(".app") }
            
            for item in appFiles {
                let appPath = "\(applicationsPath)/\(item)"
                let appName = String(item.dropLast(4))
                
                var appInfo: [String: Any] = [
                    "name": appName,
                    "path": appPath
                ]
                
                if let bundleId = getBundleIdentifierFast(for: appPath) {
                    appInfo["bundleIdentifier"] = bundleId
                }
                
                applications.append(appInfo)
            }
            
            catalog["applications"] = applications
            catalog["totalCount"] = applications.count
            catalog["timestamp"] = ISO8601DateFormatter().string(from: Date())
            catalog["source"] = "Applications folder scan"
            
            print("✅ Found \(applications.count) applications")
            
        } catch {
            catalog["error"] = "Failed to read Applications folder: \(error.localizedDescription)"
            catalog["applications"] = []
            catalog["totalCount"] = 0
            print("❌ Failed to scan Applications folder: \(error)")
        }
        
        return catalog
    }
    
    static func generateTextSummary(_ catalog: [String: Any]) -> String {
        guard let applications = catalog["applications"] as? [[String: Any]] else {
            return "No applications found"
        }
        
        var summary = "AVAILABLE APPLICATIONS (\(applications.count) total):\n"
        summary += "=" + String(repeating: "=", count: 50) + "\n"
        
        for app in applications.sorted(by: { 
            ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "")
        }) {
            let name = app["name"] as? String ?? "Unknown"
            let bundleId = app["bundleIdentifier"] as? String ?? "unknown"
            summary += "• \(name) (\(bundleId))\n"
        }
        
        if let timestamp = catalog["timestamp"] as? String {
            summary += "\nGenerated: \(timestamp)\n"
        }
        
        return summary
    }
    
    static func generateCompressedFormat(_ catalog: [String: Any]) -> String {
        guard let applications = catalog["applications"] as? [[String: Any]] else {
            return "apps(0)|"
        }
        
        // Extract app names with full bundle IDs (minus redundant "com.")
        var appEntries: [String] = []
        for app in applications {
            if let name = app["name"] as? String {
                if let bundleId = app["bundleIdentifier"] as? String {
                    let cleanBundleId = bundleId.hasPrefix("com.") ? String(bundleId.dropFirst(4)) : bundleId
                    appEntries.append("\(name)(\(cleanBundleId))")
                } else {
                    // Fallback if no bundle ID available
                    appEntries.append("\(name)(unknown)")
                }
            }
        }
        
        appEntries.sort()
        let totalCount = applications.count
        let appList = appEntries.joined(separator: ",")
        
        return "apps(\(totalCount))|\(appList)"
    }
    
    private static func getBundleIdentifierFast(for appPath: String) -> String? {
        let infoPlistPath = "\(appPath)/Contents/Info.plist"
        
        if let plistData = FileManager.default.contents(atPath: infoPlistPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
           let bundleId = plist["CFBundleIdentifier"] as? String {
            return bundleId
        }
        
        return nil
    }
}

// Main execution
print("📱 Generating Application Catalog...")
let catalog = ApplicationCatalog.generateCatalog()
let textSummary = ApplicationCatalog.generateTextSummary(catalog)
let compressedFormat = ApplicationCatalog.generateCompressedFormat(catalog)

// Save to text file (human-readable)
let outputPath = "available_applications.txt"
do {
    try textSummary.write(toFile: outputPath, atomically: true, encoding: .utf8)
    print("💾 Human-readable catalog saved to: \(outputPath)")
} catch {
    print("❌ Failed to save text file: \(error)")
}

// Save JSON version (complete data)
let jsonOutputPath = "available_applications.json"
do {
    let jsonData = try JSONSerialization.data(withJSONObject: catalog, options: .prettyPrinted)
    try jsonData.write(to: URL(fileURLWithPath: jsonOutputPath))
    print("💾 JSON catalog saved to: \(jsonOutputPath)")
} catch {
    print("❌ Failed to save JSON file: \(error)")
}

// Save compressed format (AI-optimized)
let compressedOutputPath = "available_applications_compressed.txt"
do {
    try compressedFormat.write(toFile: compressedOutputPath, atomically: true, encoding: .utf8)
    print("💾 Compressed catalog saved to: \(compressedOutputPath)")
    print("📊 Compression: \(compressedFormat.count) bytes (vs \(try JSONSerialization.data(withJSONObject: catalog).count) bytes JSON)")
} catch {
    print("❌ Failed to save compressed file: \(error)")
}

print("\n🎉 Catalog generation complete!")
print("📁 Generated files:")
print("   📄 \(outputPath) - Human-readable list")
print("   📋 \(jsonOutputPath) - Complete JSON data") 
print("   🗜️  \(compressedOutputPath) - AI-optimized format")
print("\n📊 Compressed format preview:")
print(compressedFormat) 