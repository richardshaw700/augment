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
        
        // Step 1: Sweep through all 780 grid positions (26 columns × 30 rows)
        for columnIndex in 0..<UniversalGrid.COLUMNS {
            for rowIndex in 0..<UniversalGrid.ROWS {
                let column = Character(UnicodeScalar(65 + columnIndex)!)
                let row = rowIndex + 1
                let gridPos = AdaptiveGridPosition(column, row)
                
                // Find the best element for this grid cell
                if let bestElement = findBestElementForCell(gridPos, elements: elements) {
                    gridCellMap[gridPos] = bestElement
                }
            }
        }
        
        // Step 2: Convert to GridMappedElements and deduplicate
        var uniqueElements: [String: GridMappedElement] = [:]
        
        for (gridPos, element) in gridCellMap {
            let gridElement = GridMappedElement(
                originalElement: element,
                gridPosition: gridPos,
                mappingConfidence: calculateMappingConfidence(element, gridPos: gridPos),
                importance: calculateElementImportance(element)
            )
            
            // Use element ID as key to deduplicate elements that span multiple cells
            if let existing = uniqueElements[element.id] {
                // Keep the element with higher importance or better position
                if gridElement.importance > existing.importance ||
                   (gridElement.importance == existing.importance && 
                    isMoreCentralPosition(gridPos, vs: existing.gridPosition)) {
                    uniqueElements[element.id] = gridElement
                }
            } else {
                uniqueElements[element.id] = gridElement
            }
        }
        
        let result = Array(uniqueElements.values).sorted { $0.importance > $1.importance }
        print("🗂️ Grid mapping complete: \(result.count) unique elements")
        return result
    }
    
    private func findBestElementForCell(_ gridPos: AdaptiveGridPosition, elements: [UIElement]) -> UIElement? {
        let cellBounds = coordinateSystem.cellBounds(for: gridPos)
        let cellCenter = CGPoint(x: cellBounds.midX, y: cellBounds.midY)
        
        var candidates: [(element: UIElement, score: Double)] = []
        
        for element in elements {
            let elementBounds = CGRect(origin: element.position, size: element.size)
            
            // Check if element intersects with this grid cell
            if cellBounds.intersects(elementBounds) {
                let score = calculateCellElementScore(element, cellBounds: cellBounds, cellCenter: cellCenter)
                candidates.append((element, score))
            }
        }
        
        // Return the highest scoring element for this cell
        return candidates.max { $0.score < $1.score }?.element
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
        let center = AdaptiveGridPosition("M", 15) // Middle of 26x30 grid
        
        let dist1 = abs(pos1.columnIndex - center.columnIndex) + abs(pos1.rowIndex - center.rowIndex)
        let dist2 = abs(pos2.columnIndex - center.columnIndex) + abs(pos2.rowIndex - center.rowIndex)
        
        return dist1 < dist2
    }
} 