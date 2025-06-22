import Foundation

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    let type: MessageType
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), type: MessageType = .text) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.type = type
    }
    
    // MARK: - Message Types
    enum MessageType: Equatable {
        case text
        case tool
        case error
        case system
        case thinking
        case completed
        
        var icon: String {
            switch self {
            case .text: return "🤖"
            case .tool: return "🔧"
            case .error: return "⚠️"
            case .system: return "ℹ️"
            case .thinking: return "💭"
            case .completed: return "✅"
            }
        }
        
        var avatarColorName: String {
            switch self {
            case .text: return "green"
            case .tool: return "orange"
            case .error: return "red"
            case .system: return "gray"
            case .thinking: return "blue"
            case .completed: return "green"
            }
        }
    }
    
    // MARK: - Convenience Initializers
    static func userMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: true, type: .text)
    }
    
    static func gptMessage(_ content: String, type: MessageType = .text) -> ChatMessage {
        ChatMessage(content: content, isUser: false, type: type)
    }
    
    static func systemMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: false, type: .system)
    }
    
    static func errorMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: false, type: .error)
    }
    
    static func toolMessage(_ content: String) -> ChatMessage {
        ChatMessage(content: content, isUser: false, type: .tool)
    }
    
    // MARK: - Utility Methods
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var truncatedContent: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    var isEmpty: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Chat Message Extensions
extension ChatMessage {
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Array Extensions
extension Array where Element == ChatMessage {
    var lastUserMessage: ChatMessage? {
        last { $0.isUser }
    }
    
    var lastGPTMessage: ChatMessage? {
        last { !$0.isUser }
    }
    
    func messages(of type: ChatMessage.MessageType) -> [ChatMessage] {
        filter { $0.type == type }
    }
    
    func userMessages() -> [ChatMessage] {
        filter { $0.isUser }
    }
    
    func gptMessages() -> [ChatMessage] {
        filter { !$0.isUser }
    }
}