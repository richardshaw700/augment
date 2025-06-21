import Foundation
import AppKit

class ApplicationCatalog {
    
    // MARK: - Compressed Format Structure
    
    struct CompressedApp {
        let id: String          // Short identifier for AI reference
        let name: String        // Display name
        let category: String    // App category for context
        let bundleId: String    // Full bundle identifier for mapping
    }
    
    // MARK: - Main Catalog Generation
    
    static func generateCatalog() -> [String: Any] {
        var catalog: [String: Any] = [:]
        var applications: [[String: Any]] = []
        
        let applicationsPath = "/Applications"
        let fileManager = FileManager.default
        
        print("🔍 Scanning Applications folder...")
        
        do {
            // Get only .app files directly for performance
            let contents = try fileManager.contentsOfDirectory(atPath: applicationsPath)
            let appFiles = contents.filter { $0.hasSuffix(".app") }
            
            for item in appFiles {
                let appPath = "\(applicationsPath)/\(item)"
                let appName = String(item.dropLast(4)) // Remove .app extension
                
                // Minimal app info for performance
                var appInfo: [String: Any] = [
                    "name": appName,
                    "path": appPath
                ]
                
                // Only get bundle ID if it's quick
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
    
    // MARK: - Save/Load Catalog
    
    static func saveCatalogToFile(_ catalog: [String: Any], filePath: String) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: catalog, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: filePath))
            print("💾 Application catalog saved to: \(filePath)")
        } catch {
            print("❌ Failed to save catalog: \(error)")
        }
    }
    
    static func loadCatalogFromFile(_ filePath: String) -> [String: Any]? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let catalog = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            print("📂 Loaded application catalog from: \(filePath)")
            return catalog
        } catch {
            print("❌ Failed to load catalog: \(error)")
            return nil
        }
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
    
    // MARK: - Helper Methods
    
    private static func getBundleIdentifierFast(for appPath: String) -> String? {
        // Fast path - read Info.plist directly instead of creating Bundle
        let infoPlistPath = "\(appPath)/Contents/Info.plist"
        
        if let plistData = FileManager.default.contents(atPath: infoPlistPath),
           let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
           let bundleId = plist["CFBundleIdentifier"] as? String {
            return bundleId
        }
        
        return nil
    }
    
    // MARK: - Main Compression Method
    
    static func compressApplicationCatalog() -> String {
        guard let jsonData = loadApplicationJSON(),
              let apps = parseApplicationJSON(jsonData) else {
            return "apps:none"
        }
        
        let compressedApps = apps.map { compressApplication($0) }
        let categorizedApps = categorizeAndSort(compressedApps)
        
        return formatCompressedCatalog(categorizedApps)
    }
    
    // MARK: - JSON Loading and Parsing
    
    private static func loadApplicationJSON() -> Data? {
        let jsonPath = "src/ui_inspector/system_inspector/available_applications.json"
        return try? Data(contentsOf: URL(fileURLWithPath: jsonPath))
    }
    
    private static func parseApplicationJSON(_ data: Data) -> [[String: Any]]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let applications = json["applications"] as? [[String: Any]] else {
            return nil
        }
        return applications
    }
    
    // MARK: - Application Compression
    
    private static func compressApplication(_ app: [String: Any]) -> CompressedApp {
        let name = app["name"] as? String ?? "Unknown"
        let bundleId = app["bundleIdentifier"] as? String ?? "unknown"
        
        // Generate short ID (first 3 chars + unique suffix)
        let shortId = generateShortId(name: name, bundleId: bundleId)
        
        // Categorize application
        let category = categorizeApplication(name: name, bundleId: bundleId)
        
        return CompressedApp(
            id: shortId,
            name: name,
            category: category,
            bundleId: bundleId
        )
    }
    
    private static func generateShortId(name: String, bundleId: String) -> String {
        // Use first 3 characters of name + hash suffix for uniqueness
        let prefix = String(name.prefix(3).lowercased())
        let hash = abs(bundleId.hashValue) % 99
        return "\(prefix)\(String(format: "%02d", hash))"
    }
    
    private static func categorizeApplication(name: String, bundleId: String) -> String {
        let lowerName = name.lowercased()
        let lowerBundle = bundleId.lowercased()
        
        // Development tools
        if ["xcode", "cursor", "sourcetree", "postman", "mongodb"].contains(where: { lowerName.contains($0) }) ||
           ["xcode", "editor", "git", "api", "database"].contains(where: { lowerBundle.contains($0) }) {
            return "dev"
        }
        
        // Productivity
        if ["notion", "obsidian", "pages", "things", "calendr", "table"].contains(where: { lowerName.contains($0) }) ||
           ["productivity", "notes", "calendar", "todo"].contains(where: { lowerBundle.contains($0) }) {
            return "prod"
        }
        
        // Communication
        if ["slack", "chatgpt", "session"].contains(where: { lowerName.contains($0) }) ||
           ["chat", "communication", "messaging"].contains(where: { lowerBundle.contains($0) }) {
            return "comm"
        }
        
        // Media & Design
        if ["figma", "capcut", "spotify", "astro"].contains(where: { lowerName.contains($0) }) ||
           ["design", "media", "music", "video"].contains(where: { lowerBundle.contains($0) }) {
            return "media"
        }
        
        // Utilities
        if ["whatfont", "alter", "vpn", "sqlite"].contains(where: { lowerName.contains($0) }) ||
           ["utility", "tool", "vpn", "font"].contains(where: { lowerBundle.contains($0) }) {
            return "util"
        }
        
        // System/Apple apps
        if lowerBundle.contains("apple") || ["safari", "pages"].contains(lowerName) {
            return "sys"
        }
        
        // Default category
        return "app"
    }
    
    // MARK: - Categorization and Sorting
    
    private static func categorizeAndSort(_ apps: [CompressedApp]) -> [String: [CompressedApp]] {
        var categorized: [String: [CompressedApp]] = [:]
        
        for app in apps {
            if categorized[app.category] == nil {
                categorized[app.category] = []
            }
            categorized[app.category]?.append(app)
        }
        
        // Sort within each category
        for category in categorized.keys {
            categorized[category]?.sort { $0.name < $1.name }
        }
        
        return categorized
    }
    
    // MARK: - Output Formatting
    
    private static func formatCompressedCatalog(_ categorizedApps: [String: [CompressedApp]]) -> String {
        var output: [String] = []
        
        // Category order for logical grouping
        let categoryOrder = ["sys", "dev", "prod", "comm", "media", "util", "app"]
        let categoryNames = [
            "sys": "System",
            "dev": "Development", 
            "prod": "Productivity",
            "comm": "Communication",
            "media": "Media",
            "util": "Utilities",
            "app": "Applications"
        ]
        
        for category in categoryOrder {
            guard let apps = categorizedApps[category], !apps.isEmpty else { continue }
            
            let categoryName = categoryNames[category] ?? category
            let appList = apps.map { "\($0.id):\($0.name)" }.joined(separator: ",")
            output.append("\(category)[\(appList)]")
        }
        
        let totalCount = categorizedApps.values.flatMap { $0 }.count
        return "apps(\(totalCount))|\(output.joined(separator: "|"))"
    }
    
    // MARK: - Reverse Mapping Support
    
    static func getBundleIdFromShortId(_ shortId: String) -> String? {
        guard let jsonData = loadApplicationJSON(),
              let apps = parseApplicationJSON(jsonData) else {
            return nil
        }
        
        for app in apps {
            let name = app["name"] as? String ?? "Unknown"
            let bundleId = app["bundleIdentifier"] as? String ?? "unknown"
            let generatedId = generateShortId(name: name, bundleId: bundleId)
            
            if generatedId == shortId {
                return bundleId
            }
        }
        
        return nil
    }
    
    static func getFullAppInfo(_ shortId: String) -> [String: Any]? {
        guard let jsonData = loadApplicationJSON(),
              let apps = parseApplicationJSON(jsonData) else {
            return nil
        }
        
        for app in apps {
            let name = app["name"] as? String ?? "Unknown"
            let bundleId = app["bundleIdentifier"] as? String ?? "unknown"
            let generatedId = generateShortId(name: name, bundleId: bundleId)
            
            if generatedId == shortId {
                return app
            }
        }
        
        return nil
    }
} 