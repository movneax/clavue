import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    let timestamp = Date()
    var isStreaming: Bool = false
    var thinking: String?
    var toolCalls: [ToolActivity] = []

    enum Role {
        case user
        case assistant
    }
}
