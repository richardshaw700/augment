import Foundation
import CoreGraphics

// MARK: - Shape Detection Data Models

struct ShapeContour {
    let path: CGPath
    let boundingBox: CGRect
    let pointCount: Int
    let aspectRatio: CGFloat
    let area: CGFloat
    let confidence: Double
}

struct ClassifiedShape {
    let contour: ShapeContour
    let type: ShapeType
    let uiRole: UIRole
    let confidence: Double
}

struct UIShapeCandidate {
    let contour: CGPath
    let boundingBox: CGRect
    let type: ShapeType
    let uiRole: UIRole
    let interactionType: InteractionType
    let confidence: Double
    let area: CGFloat
    let aspectRatio: CGFloat
    let corners: [CGPoint]
    let curvature: Double
}

// MARK: - Enums

enum ShapeType: String, CaseIterable {
    case circle = "circle"
    case rectangle = "rectangle"
    case roundedRectangle = "rounded_rectangle"
    case irregular = "irregular"
    case line = "line"
}

enum UIRole: String, CaseIterable {
    case button = "button"
    case icon = "icon"
    case inputField = "input_field"
    case decoration = "decoration"
    case container = "container"
    case unknown = "unknown"
}

enum InteractionType: String, CaseIterable {
    case textInput = "text_input"
    case button = "button"
    case iconButton = "icon_button"
    case closeButton = "close_button"
    case menuButton = "menu_button"
    case slider = "slider"
    case toggle = "toggle"
    case dropdown = "dropdown"
    case tab = "tab"
    case unknown = "unknown"
}