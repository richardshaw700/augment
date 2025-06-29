import Foundation
import AppKit

// MARK: - UIElement Extensions

extension UIElement {
    init(type: String, position: CGPoint, size: CGSize, 
         accessibilityData: AccessibilityData?, ocrData: OCRData?, 
         isClickable: Bool, confidence: Double) {
        self.id = UUID().uuidString
        self.type = type
        self.position = position
        self.size = size
        self.accessibilityData = accessibilityData
        self.ocrData = ocrData
        self.isClickable = isClickable
        self.confidence = confidence
        
        // Enhanced semantic understanding
        self.semanticMeaning = UIElement.inferSemanticMeaning(accessibilityData, ocrData)
        self.actionHint = UIElement.generateActionHint(accessibilityData, ocrData, isClickable)
        
        // Set visualText from accessibility value (for text fields) or OCR text
        if let accValue = accessibilityData?.value, !accValue.isEmpty {
            self.visualText = accValue  // Use accessibility value (e.g., URL in address bar)
        } else {
            self.visualText = ocrData?.text  // Fallback to OCR text
        }
        
        self.interactions = UIElement.generateInteractions(accessibilityData, isClickable)
        self.context = UIElement.generateContext(accessibilityData, ocrData, position)
    }
    
    // MARK: - Semantic Understanding
    
    private static func inferSemanticMeaning(_ accData: AccessibilityData?, _ ocrData: OCRData?) -> String {
        if let accData = accData, let ocrData = ocrData {
            return "\(accData.role) with text '\(ocrData.text)'"
        } else if let accData = accData {
            return accData.description ?? accData.role
        } else if let ocrData = ocrData {
            return "Text content: '\(ocrData.text)'"
        } else {
            return "Unknown element"
        }
    }
    
    // MARK: - Action Hint Generation
    
    private static func generateActionHint(_ accData: AccessibilityData?, _ ocrData: OCRData?, _ isClickable: Bool) -> String? {
        guard isClickable else { return nil }
        
        if let ocrText = ocrData?.text.lowercased() {
            if ocrText.contains("close") || ocrText.contains("×") {
                return "Click to close"
            } else if ocrText.contains("save") {
                return "Click to save"
            } else if ocrText.contains("search") {
                return "Click to search"
            } else if ocrText.contains("share") {
                return "Click to share"
            } else if ocrText.contains("edit") {
                return "Click to edit"
            }
        }
        
        if let accDesc = accData?.description {
            return "Click \(accDesc)"
        }
        
        return "Clickable element"
    }
    
    // MARK: - Interaction Generation
    
    private static func generateInteractions(_ accData: AccessibilityData?, _ isClickable: Bool) -> [String] {
        var interactions: [String] = []
        
        if isClickable {
            interactions.append("click")
        }
        
        if let accData = accData {
            switch accData.role {
            case "AXTextField":
                interactions.append(contentsOf: ["type", "select_all", "copy", "paste"])
            case "AXButton", "AXMenuItem":
                interactions.append("double_click")
            case "AXSlider":
                interactions.append(contentsOf: ["drag", "arrow_keys"])
            case "AXCheckBox", "AXRadioButton":
                interactions.append("toggle")
            case "AXScrollArea":
                interactions.append(contentsOf: ["scroll", "swipe"])
            case "AXPopUpButton":
                interactions.append("dropdown")
            case "AXImage", "AXGroup":
                interactions.append("right_click")
            default:
                break
            }
        }
        
        return interactions
    }
    
    // MARK: - Context Generation
    
    private static func generateContext(_ accData: AccessibilityData?, _ ocrData: OCRData?, _ position: CGPoint) -> ElementContext? {
        guard let accData = accData else { return nil }
        
        let purpose = inferPurpose(accData, ocrData)
        let region = inferRegion(position)
        let navigationPath = generateNavigationPath(accData)
        let availableActions = generateAvailableActions(accData, ocrData)
        
        return ElementContext(
            purpose: purpose,
            region: region,
            navigationPath: navigationPath,
            availableActions: availableActions
        )
    }
    
    // MARK: - Purpose Inference
    
    private static func inferPurpose(_ accData: AccessibilityData, _ ocrData: OCRData?) -> String {
        if let text = ocrData?.text.lowercased() {
            if text.contains("close") || text.contains("×") { return "window_control" }
            if text.contains("save") { return "file_operation" }
            if text.contains("search") { return "search" }
            if text.contains("share") { return "sharing" }
        }
        
        switch accData.role {
        case "AXButton": return "action_trigger"
        case "AXTextField": return "text_input"
        case "AXStaticText": return "information_display"
        case "AXImage": return "visual_content"
        case "AXGroup": return "content_container"
        default: return "ui_element"
        }
    }
    
    // MARK: - Region Inference
    
    private static func inferRegion(_ position: CGPoint) -> String {
        if position.y < 100 { return "toolbar" }
        if position.x < 200 { return "sidebar" }
        if position.y > 500 { return "status_bar" }
        return "main_content"
    }
    
    // MARK: - Navigation Path Generation
    
    private static func generateNavigationPath(_ accData: AccessibilityData) -> String {
        var path = accData.role
        if let parent = accData.parent {
            path = "\(parent) > \(path)"
        }
        if let title = accData.title {
            path += "[\(title)]"
        }
        return path
    }
    
    // MARK: - Available Actions Generation
    
    private static func generateAvailableActions(_ accData: AccessibilityData, _ ocrData: OCRData?) -> [String] {
        var actions: [String] = []
        
        switch accData.role {
        case "AXButton":
            actions.append("activate")
        case "AXTextField":
            actions.append(contentsOf: ["focus", "type", "clear"])
        case "AXImage":
            actions.append(contentsOf: ["view", "save_as"])
        case "AXGroup":
            if !accData.children.isEmpty {
                actions.append("expand")
            }
        default:
            break
        }
        
        if let text = ocrData?.text.lowercased() {
            if text.contains("download") { actions.append("download") }
            if text.contains("open") { actions.append("open") }
            if text.contains("edit") { actions.append("edit") }
        }
        
        return actions
    }
}