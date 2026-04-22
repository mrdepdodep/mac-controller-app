import SwiftUI

enum Theme {
    static let bg      = Color(hex: "#07090E")
    static let surface = Color(hex: "#0B0E1A")
    static let surf2   = Color(hex: "#111626")
    static let surf3   = Color(hex: "#192038")
    static let accent  = Color(hex: "#7C6AF7")
    static let accentD = Color(hex: "#4B42A8")
    static let success = Color(hex: "#34D399")
    static let warning = Color(hex: "#FBBF24")
    static let userC   = Color(hex: "#818CF8")
    static let text    = Color(hex: "#E4EAF4")
    static let subtext = Color(hex: "#7C8BA4")
    static let muted   = Color(hex: "#3A4A62")
    static let border  = Color(hex: "#1C2540")
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
