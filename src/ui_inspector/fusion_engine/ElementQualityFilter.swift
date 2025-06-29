import Foundation
import AppKit

/// Filters UI elements based on quality and meaningfulness criteria
class ElementQualityFilter {
    
    /// Filter out low-quality elements while preserving meaningful ones
    func filterMeaningfulElements(_ elements: [UIElement]) -> [UIElement] {
        return elements.filter { element in
            // Keep all non-button elements (reduced filtering)
            guard element.type.contains("Button") || element.isClickable else {
                return true
            }
            
            // More lenient filtering criteria for buttons and clickable elements
            return hasAnyMeaningfulContext(element)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func hasAnyMeaningfulContext(_ element: UIElement) -> Bool {
        let size = element.size
        let area = size.width * size.height
        
        // Allow smaller buttons (window controls, icons)
        if area < 100 { // Very small elements might still be important (window controls)
            return hasSpecialUIContext(element)
        }
        
        // Check for any meaningful context (more lenient)
        let hasText = hasAnyText(element)
        let hasAccessibility = hasAnyAccessibility(element)
        let hasAction = hasAnyActionHint(element)
        
        // Must have at least one piece of context
        return hasText || hasAccessibility || hasAction
    }
    
    private func hasSpecialUIContext(_ element: UIElement) -> Bool {
        // Check for window controls or system UI elements
        if let accessibility = element.accessibilityData {
            let role = accessibility.role
            if role.contains("Close") || role.contains("Minimize") || role.contains("Zoom") || 
               role.contains("Window") || role.contains("Control") {
                return true
            }
        }
        
        // Check for small but important UI text
        if let text = element.visualText?.lowercased() {
            let systemKeywords = ["×", "⚫", "🟡", "🟢", "close", "min", "max"]
            return systemKeywords.contains(where: { text.contains($0) })
        }
        
        return false
    }
    
    private func hasAnyText(_ element: UIElement) -> Bool {
        guard let text = element.visualText?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        
        // Allow any non-empty text (removed length restriction)
        return !text.isEmpty
    }
    
    private func hasAnyAccessibility(_ element: UIElement) -> Bool {
        guard let accessibility = element.accessibilityData else {
            return false
        }
        
        // Check for any description or title (more lenient)
        if let description = accessibility.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return true
        }
        
        if let title = accessibility.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return true
        }
        
        return false
    }
    
    private func hasAnyActionHint(_ element: UIElement) -> Bool {
        guard let actionHint = element.actionHint?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        
        // Allow any action hint
        return !actionHint.isEmpty
    }
} 