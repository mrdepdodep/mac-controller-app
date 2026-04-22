// Build:  swift build  (inside MacControl/)
// Run:    swift run
// Xcode:  open Package.swift

import SwiftUI

@main
struct MacControlApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 780, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
