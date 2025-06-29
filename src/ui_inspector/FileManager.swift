import Foundation

// MARK: - File Management Utility

class UIInspectorFileManager {
    private let outputDirectory: String
    private let maxFiles: Int
    
    init(outputDirectory: String = "output", maxFiles: Int = 20) {
        // Get the directory where the executable is located
        let executablePath = CommandLine.arguments[0]
        let executableDir = URL(fileURLWithPath: executablePath).deletingLastPathComponent().path
        self.outputDirectory = "\(executableDir)/\(outputDirectory)"
        self.maxFiles = maxFiles
        
        // Ensure output directory exists
        createOutputDirectoryIfNeeded()
    }
    
    private func createOutputDirectoryIfNeeded() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: outputDirectory) {
            do {
                try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
                print("📁 Created output directory: \(outputDirectory)")
            } catch {
                print("❌ Failed to create output directory: \(error)")
            }
        }
    }
    
    func generateFilePaths(timestamp: String) -> (rawPath: String, cleanedPath: String, compressedPath: String) {
        let rawPath = "\(outputDirectory)/ui_raw_\(timestamp).json"
        let cleanedPath = "\(outputDirectory)/ui_cleaned_\(timestamp).json"
        let compressedPath = "\(outputDirectory)/ui_compressed_\(timestamp).txt"
        return (rawPath, cleanedPath, compressedPath)
    }
    
    func saveFiles(jsonData: Data, compressedFormat: String, timestamp: String) throws -> (rawPath: String, cleanedPath: String, compressedPath: String) {
        let paths = generateFilePaths(timestamp: timestamp)
        
        // Write raw JSON file
        try jsonData.write(to: URL(fileURLWithPath: paths.rawPath))
        
        // Generate and write cleaned JSON file
        let cleanedData = try generateCleanedJSON(from: jsonData)
        try cleanedData.write(to: URL(fileURLWithPath: paths.cleanedPath))
        
        // Use the passed-in compressed format (from OutputManager.toCompressed)
        try compressedFormat.write(to: URL(fileURLWithPath: paths.compressedPath), atomically: false, encoding: String.Encoding.utf8)
        
        // Clean up old files after successful write
        cleanupOldFiles()
        
        return paths
    }
    
    // DEPRECATED: Moved to DataCleaningService.generateCleanedJSON
    // This method is kept for backward compatibility only
    func generateCleanedJSON(from rawData: Data) throws -> Data {
        return try DataCleaningService.generateCleanedJSON(from: rawData)
    }
    
    // DEPRECATED: Use CompressionService.generateCompressedFormat instead
    // This method is kept for backward compatibility but should not be used
    
    // DEPRECATED: These methods have been moved to DataCleaningService
    
    private func cleanupOldFiles() {
        let fileManager = FileManager.default
        
        do {
            // Get all files in output directory
            let files = try fileManager.contentsOfDirectory(atPath: outputDirectory)
            
            // Filter for our output files (raw, cleaned, compressed, and logs)
            let outputFiles = files.filter { file in
                (file.hasPrefix("ui_raw_") && file.hasSuffix(".json")) ||
                (file.hasPrefix("ui_cleaned_") && file.hasSuffix(".json")) ||
                (file.hasPrefix("ui_compressed_") && file.hasSuffix(".txt")) ||
                // Legacy support for old ui_map_ files
                (file.hasPrefix("ui_map_") && file.hasSuffix(".json"))
            }
            
            // Keep performance logs and other system files
            let systemFiles = files.filter { file in
                file == "latest_performance_logs.txt" ||
                file == "latest_run_logs.txt" ||
                file.hasSuffix(".log")
            }
            
            print("📁 Output directory status: \(outputFiles.count) files, \(systemFiles.count) system files")
            
            // If we exceed the limit, remove oldest files
            if outputFiles.count > maxFiles {
                // Get file creation dates
                var fileInfos: [(name: String, date: Date)] = []
                
                for file in outputFiles {
                    let filePath = "\(outputDirectory)/\(file)"
                    let attributes = try fileManager.attributesOfItem(atPath: filePath)
                    if let creationDate = attributes[.creationDate] as? Date {
                        fileInfos.append((name: file, date: creationDate))
                    }
                }
                
                // Sort by date (oldest first)
                fileInfos.sort { $0.date < $1.date }
                
                // Calculate how many to remove
                let filesToRemove = outputFiles.count - maxFiles
                
                print("🧹 Cleanup needed: removing \(filesToRemove) oldest files (keeping \(maxFiles) most recent)")
                
                // Remove oldest files
                var removedCount = 0
                for i in 0..<min(filesToRemove, fileInfos.count) {
                    let fileToRemove = fileInfos[i].name
                    let filePath = "\(outputDirectory)/\(fileToRemove)"
                    
                    do {
                        try fileManager.removeItem(atPath: filePath)
                        removedCount += 1
                        if removedCount <= 3 { // Show first few removals
                            print("  🗑️  Removed: \(fileToRemove)")
                        }
                    } catch {
                        print("  ⚠️  Failed to remove \(fileToRemove): \(error)")
                    }
                }
                
                if removedCount > 3 {
                    print("  🗑️  ... and \(removedCount - 3) more files")
                }
                
                print("✅ Cleanup complete: \(removedCount) files removed, \(outputFiles.count - removedCount) files kept")
            } else {
                print("✅ No cleanup needed: \(outputFiles.count)/\(maxFiles) files")
            }
            
        } catch {
            print("⚠️  Cleanup failed: \(error)")
        }
    }
    
    func getOutputDirectory() -> String {
        return outputDirectory
    }
    
    func getFileCount() -> Int {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: outputDirectory)
            let outputFiles = files.filter { file in
                (file.hasPrefix("ui_raw_") && file.hasSuffix(".json")) ||
                (file.hasPrefix("ui_cleaned_") && file.hasSuffix(".json")) ||
                (file.hasPrefix("ui_compressed_") && file.hasSuffix(".txt")) ||
                // Legacy support
                (file.hasPrefix("ui_map_") && file.hasSuffix(".json"))
            }
            return outputFiles.count
        } catch {
            return 0
        }
    }
    
    // Get list of recent files for debugging
    func getRecentFiles(limit: Int = 5) -> [String] {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: outputDirectory)
            let outputFiles = files.filter { file in
                (file.hasPrefix("ui_raw_") && file.hasSuffix(".json")) ||
                (file.hasPrefix("ui_cleaned_") && file.hasSuffix(".json")) ||
                (file.hasPrefix("ui_compressed_") && file.hasSuffix(".txt")) ||
                // Legacy support
                (file.hasPrefix("ui_map_") && file.hasSuffix(".json"))
            }
            
            // Get file creation dates and sort
            var fileInfos: [(name: String, date: Date)] = []
            
            for file in outputFiles {
                let filePath = "\(outputDirectory)/\(file)"
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if let creationDate = attributes[.creationDate] as? Date {
                    fileInfos.append((name: file, date: creationDate))
                }
            }
            
            // Sort by date (newest first)
            fileInfos.sort { $0.date > $1.date }
            
            // Return just the file names, limited to requested count
            return fileInfos.prefix(limit).map { $0.name }
            
        } catch {
            return []
        }
    }
    
    // DEPRECATED: Text merging methods moved to DataCleaningService
} 
