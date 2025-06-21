import Foundation

// MARK: - File Management Utility

class UIInspectorFileManager {
    private let outputDirectory: String
    private let maxFiles: Int
    
    init(outputDirectory: String = "output", maxFiles: Int = 10) {
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
    
    func generateFilePaths(timestamp: String) -> (jsonPath: String, compressedPath: String) {
        let jsonPath = "\(outputDirectory)/ui_map_\(timestamp).json"
        let compressedPath = "\(outputDirectory)/ui_compressed_\(timestamp).txt"
        return (jsonPath, compressedPath)
    }
    
    func saveFiles(jsonData: Data, compressedFormat: String, timestamp: String) throws -> (jsonPath: String, compressedPath: String) {
        let paths = generateFilePaths(timestamp: timestamp)
        
        // Write files
        try compressedFormat.write(to: URL(fileURLWithPath: paths.compressedPath), atomically: false, encoding: String.Encoding.utf8)
        try jsonData.write(to: URL(fileURLWithPath: paths.jsonPath))
        
        // Clean up old files after successful write
        cleanupOldFiles()
        
        return paths
    }
    
    private func cleanupOldFiles() {
        let fileManager = FileManager.default
        
        do {
            // Get all files in output directory
            let files = try fileManager.contentsOfDirectory(atPath: outputDirectory)
            
            // Filter for our output files (JSON and compressed)
            let outputFiles = files.filter { file in
                file.hasPrefix("ui_map_") && file.hasSuffix(".json") ||
                file.hasPrefix("ui_compressed_") && file.hasSuffix(".txt")
            }
            
            // If we have more than maxFiles, remove the oldest ones
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
                
                // Remove oldest files
                for i in 0..<filesToRemove {
                    let fileToRemove = fileInfos[i].name
                    let filePath = "\(outputDirectory)/\(fileToRemove)"
                    
                    do {
                        try fileManager.removeItem(atPath: filePath)
                        print("🗑️  Removed old file: \(fileToRemove)")
                    } catch {
                        print("⚠️  Failed to remove old file \(fileToRemove): \(error)")
                    }
                }
                
                print("🧹 Cleanup complete: kept \(maxFiles) most recent files")
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
                file.hasPrefix("ui_map_") && file.hasSuffix(".json") ||
                file.hasPrefix("ui_compressed_") && file.hasSuffix(".txt")
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
                file.hasPrefix("ui_map_") && file.hasSuffix(".json") ||
                file.hasPrefix("ui_compressed_") && file.hasSuffix(".txt")
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
} 