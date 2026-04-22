import Foundation

struct Message: Identifiable {
    let id   = UUID()
    let sender: String
    let text: String
    let timestamp: String
    let isUser: Bool

    init(sender: String, text: String, isUser: Bool) {
        self.sender = sender
        self.text   = text
        self.isUser = isUser
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        self.timestamp = f.string(from: Date())
    }
}
