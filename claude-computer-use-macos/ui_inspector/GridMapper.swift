import Foundation
import AppKit

// MARK: - Grid Sweep Mapper

class GridSweepMapper: GridMapping {
    private let windowFrame: CGRect
    private let coordinateSystem: CoordinateSystem
    
    init(windowFrame: CGRect) {
        self.windowFrame = windowFrame
        self.coordinateSystem = CoordinateSystem(windowFrame: windowFrame)
    }
    
    func mapToGrid(_ elements: [UIElement]) -> [GridMappedElement] {
        var gridCellMap: [AdaptiveGridPosition: UIElement] = [:]
        
        // Debug: Check input elements for System/Users/Applications
        let inputSystemElements = elements.filter { $0.visualText?.lowercased().contains("system") == true }
        let inputUsersElements = elements.filter { $0.visualText?.lowercased().contains("users") == true }
        let inputApplicationsElements = elements.filter { $0.visualText?.lowercased().contains("applications") == true }
        print("🔍 DEBUG: Input elements to grid mapper:")
        print("   System elements: \(inputSystemElements.count)")
        print("   Users elements: \(inputUsersElements.count)")
        print("   Applications elements: \(inputApplicationsElements.count)")
        for element in inputSystemElements + inputUsersElements + inputApplicationsElements {
            print("   📍 '\(element.visualText ?? "")' at (\(element.position.x), \(element.position.y))")
        }
        
        // Step 1: Sweep through all grid positions
        var systemUsersChecked = false
        for columnIndex in 0..<UniversalGrid.COLUMNS {
            for rowIndex in 0..<UniversalGrid.ROWS {
                let columnString = AdaptiveGridPosition.columnString(from: columnIndex)
                let row = rowIndex + 1
                let gridPos = AdaptiveGridPosition(columnString, row)
                
                // Debug: Check if we're looking at S6 or S7
                if gridPos.description == "S6" || gridPos.description == "S7" {
                    if !systemUsersChecked {
                        print("🔍 DEBUG: Checking System/Users cells S6 and S7...")
                        systemUsersChecked = true
                    }
                    print("   Checking cell \(gridPos)...")
                }
                
                // Find the best element for this grid cell
                if let bestElement = findBestElementForCell(gridPos, elements: elements) {
                    gridCellMap[gridPos] = bestElement
                    
                    // Debug for S6/S7 cells specifically
                    if gridPos.description == "S6" || gridPos.description == "S7" {
                        print("       ✅ STORED '\(bestElement.visualText ?? "")' in gridCellMap[\(gridPos)]")
                    }
                } else {
                    // Debug: Check if this should be a System/Users cell
                    if gridPos.description == "S6" || gridPos.description == "S7" {
                        print("       ❌ NO element found for cell \(gridPos)")
                    }
                }
            }
        }
        
        // Step 2: Convert to GridMappedElements with improved deduplication for vertically stacked elements
        var positionBasedElements: [AdaptiveGridPosition: GridMappedElement] = [:]
        var elementIdTracker: [String: [AdaptiveGridPosition]] = [:]
        
        for (gridPos, element) in gridCellMap {
            let gridElement = GridMappedElement(
                originalElement: element,
                gridPosition: gridPos,
                mappingConfidence: calculateMappingConfidence(element, gridPos: gridPos),
                importance: calculateElementImportance(element)
            )
            
            // Track all positions where this element appears
            if elementIdTracker[element.id] == nil {
                elementIdTracker[element.id] = []
            }
            elementIdTracker[element.id]?.append(gridPos)
            
            // Check if this position already has an element
            if let existing = positionBasedElements[gridPos] {
                // Keep the more important element for this specific position
                if gridElement.importance > existing.importance {
                    positionBasedElements[gridPos] = gridElement
                }
            } else {
                positionBasedElements[gridPos] = gridElement
            }
        }
        
        // Step 3: Handle vertically stacked elements (same column, different rows)
        var finalElements: [String: GridMappedElement] = [:]
        
        for (elementId, positions) in elementIdTracker {
            if positions.count > 1 {
                // Element spans multiple cells - choose the best representative position
                let bestPosition = positions.max { pos1, pos2 in
                    let elem1 = positionBasedElements[pos1]!
                    let elem2 = positionBasedElements[pos2]!
                    return elem1.mappingConfidence < elem2.mappingConfidence
                }!
                
                let bestElement = positionBasedElements[bestPosition]!
                
                // Use position-based key for elements that might be vertically stacked
                let positionKey = "\(elementId)_\(bestPosition.columnString)\(bestPosition.row)"
                finalElements[positionKey] = bestElement
            } else {
                // Single position element
                let position = positions[0]
                let element = positionBasedElements[position]!
                let positionKey = "\(elementId)_\(position.columnString)\(position.row)"
                finalElements[positionKey] = element
            }
        }
        
        // Step 4: Final deduplication for truly identical elements (same text, similar position)
        var textBasedGroups: [String: [GridMappedElement]] = [:]
        
        for element in finalElements.values {
            let textKey = element.originalElement.visualText?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !textKey.isEmpty {
                if textBasedGroups[textKey] == nil {
                    textBasedGroups[textKey] = []
                }
                textBasedGroups[textKey]?.append(element)
            }
        }
        
        // Keep vertically separated elements with same text (like our folder names)
        var uniqueElements: [GridMappedElement] = []
        
        for (text, elements) in textBasedGroups {
            if elements.count > 1 {
                // Sort by row position and keep elements that are sufficiently separated vertically
                let sortedByRow = elements.sorted { $0.gridPosition.row < $1.gridPosition.row }
                var keptElements: [GridMappedElement] = []
                
                for element in sortedByRow {
                    let shouldKeep = keptElements.isEmpty || 
                                   keptElements.allSatisfy { kept in
                                       abs(kept.gridPosition.row - element.gridPosition.row) >= 2 // At least 2 rows apart
                                   }
                    
                    if shouldKeep {
                        keptElements.append(element)
                    }
                }
                
                uniqueElements.append(contentsOf: keptElements)
            } else {
                uniqueElements.append(contentsOf: elements)
            }
        }
        
        // Add elements without text content
        for element in finalElements.values {
            let hasText = !(element.originalElement.visualText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if !hasText {
                uniqueElements.append(element)
            }
        }
        
        let result = uniqueElements.sorted { $0.importance > $1.importance }
        
        // Debug output for folder detection
        let folderElements = result.filter { element in
            let text = element.originalElement.visualText?.lowercased() ?? ""
            return text.contains("applications") || text.contains("library") || text.contains("system") || text.contains("users")
        }
        
        // Debug: Check what happened to System and Users
        print("🔍 DEBUG: Checking for System/Users in all processing stages:")
        
        // Check in original gridCellMap
        let systemInGrid = gridCellMap.values.filter { $0.visualText?.lowercased().contains("system") == true }
        let usersInGrid = gridCellMap.values.filter { $0.visualText?.lowercased().contains("users") == true }
        print("   System elements in gridCellMap: \(systemInGrid.count)")
        print("   Users elements in gridCellMap: \(usersInGrid.count)")
        
        // Check in finalElements
        let systemInFinal = finalElements.values.filter { $0.originalElement.visualText?.lowercased().contains("system") == true }
        let usersInFinal = finalElements.values.filter { $0.originalElement.visualText?.lowercased().contains("users") == true }
        print("   System elements in finalElements: \(systemInFinal.count)")
        print("   Users elements in finalElements: \(usersInFinal.count)")
        
        print("🗂️ Grid mapping complete: \(result.count) unique elements")
        print("📁 Folder elements detected: \(folderElements.count)")
        for folder in folderElements {
            print("   📁 '\(folder.originalElement.visualText ?? "")' -> \(folder.gridPosition) (importance: \(folder.importance))")
        }
        return result
    }
    
    private func findBestElementForCell(_ gridPos: AdaptiveGridPosition, elements: [UIElement]) -> UIElement? {
        let cellBounds = coordinateSystem.cellBounds(for: gridPos)
        let cellCenter = CGPoint(x: cellBounds.midX, y: cellBounds.midY)
        
        var candidates: [(element: UIElement, score: Double)] = []
        
        // Debug for S6/S7 cells
        let isSystemUsersCell = gridPos.description == "S6" || gridPos.description == "S7"
        
        for element in elements {
            let elementBounds = CGRect(origin: element.position, size: element.size)
            
            // Check if element intersects with this grid cell
            if cellBounds.intersects(elementBounds) {
                let score = calculateCellElementScore(element, cellBounds: cellBounds, cellCenter: cellCenter)
                candidates.append((element, score))
                
                        // Debug all candidates for S6/S7 cells
        if isSystemUsersCell {
            print("       📊 '\(element.visualText ?? "")' at (\(element.position.x), \(element.position.y)) score: \(score)")
        }
            }
        }
        
        // Return the highest scoring element for this cell
        let bestCandidate = candidates.max { $0.score < $1.score }
        
        // Debug winner for S6/S7 cells
        if isSystemUsersCell {
            if let winner = bestCandidate {
                print("       🏆 WINNER: '\(winner.element.visualText ?? "")' with score \(winner.score)")
            } else {
                print("       ❌ No candidates found")
            }
        }
        
        return bestCandidate?.element
    }
    
    private func calculateCellElementScore(_ element: UIElement, cellBounds: CGRect, cellCenter: CGPoint) -> Double {
        let elementBounds = CGRect(origin: element.position, size: element.size)
        
        // Base score from element importance
        var score = Double(calculateElementImportance(element))
        
        // Intersection area bonus (how much of the cell does this element cover?)
        let intersection = cellBounds.intersection(elementBounds)
        let intersectionRatio = (intersection.width * intersection.height) / (cellBounds.width * cellBounds.height)
        score += intersectionRatio * 10.0
        
        // Distance penalty (prefer elements closer to cell center)
        let distance = sqrt(pow(element.position.x - cellCenter.x, 2) + pow(element.position.y - cellCenter.y, 2))
        let maxDistance = sqrt(pow(cellBounds.width/2, 2) + pow(cellBounds.height/2, 2))
        let distanceRatio = distance / maxDistance
        score -= distanceRatio * 5.0
        
        // Size appropriateness bonus (elements that fit well in the cell)
        let sizeRatio = min(elementBounds.width / cellBounds.width, elementBounds.height / cellBounds.height)
        if sizeRatio > 0.3 && sizeRatio < 2.0 {
            score += 3.0
        }
        
        return score
    }
    
    private func calculateElementImportance(_ element: UIElement) -> Int {
        var importance = 0
        
        // Role-based scoring
        if let role = element.accessibilityData?.role {
            switch role {
            case "AXButton": importance += 15
            case "AXMenuItem": importance += 12
            case "AXTextField": importance += 10
            case "AXStaticText": importance += 5
            case "AXImage": importance += 3
            case "AXRow": importance += 2
            case "AXCell": importance += 1
            default: importance += 1
            }
        }
        
        // Interactivity bonus
        if element.isClickable { importance += 10 }
        
        // Size bonus for prominent elements
        let area = element.size.width * element.size.height
        if area > 5000 { importance += 5 }
        else if area > 2000 { importance += 3 }
        
        // Text content bonus
        if let text = element.visualText, !text.isEmpty {
            importance += min(text.count / 10, 5)
            
            // Navigation keywords bonus
            let navWords = ["downloads", "applications", "documents", "desktop", "airdrop", 
                           "recents", "favorites", "network", "macintosh", "icloud", "shared"]
            let lowercaseText = text.lowercased()
            if navWords.contains(where: { lowercaseText.contains($0) }) {
                importance += 25 // Highest priority for navigation items
            }
        }
        
        return importance
    }
    
    private func calculateMappingConfidence(_ element: UIElement, gridPos: AdaptiveGridPosition) -> Double {
        let cellBounds = coordinateSystem.cellBounds(for: gridPos)
        let elementBounds = CGRect(origin: element.position, size: element.size)
        
        let intersection = cellBounds.intersection(elementBounds)
        let intersectionArea = intersection.width * intersection.height
        let elementArea = elementBounds.width * elementBounds.height
        
        if elementArea == 0 { return 0.5 }
        
        let overlapRatio = intersectionArea / elementArea
        return min(1.0, max(0.0, overlapRatio))
    }
    
    private func isMoreCentralPosition(_ pos1: AdaptiveGridPosition, vs pos2: AdaptiveGridPosition) -> Bool {
        let center = AdaptiveGridPosition("T", 25) // Middle of 40x50 grid (T=20th column)
        
        let dist1 = abs(pos1.columnIndex - center.columnIndex) + abs(pos1.rowIndex - center.rowIndex)
        let dist2 = abs(pos2.columnIndex - center.columnIndex) + abs(pos2.rowIndex - center.rowIndex)
        
        return dist1 < dist2
    }
} 