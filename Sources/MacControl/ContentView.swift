import SwiftUI

// MARK: - Root

struct ContentView: View {
    @StateObject private var engine = CommandEngine()
    @State  private var inputText   = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HeaderView(engine: engine)
                sep
                ChatScrollView(messages: engine.messages)
                sep
                SuggestionsView(suggestions: engine.suggestions) { s in
                    inputText = s; focused = true
                    engine.updateSuggestions(for: s)
                }
                InputBarView(
                    text:      $inputText,
                    focused:   $focused,
                    isRunning: engine.isRunning,
                    onSubmit:  { submit(inputText) }
                )
            }
        }
        .preferredColorScheme(.dark)
        .background(WindowConfigurator())
        .onAppear { engine.boot(); focused = true }
        .onChange(of: inputText) { engine.updateSuggestions(for: $0) }
    }

    private var sep: some View {
        Rectangle().fill(Theme.border).frame(height: 1)
    }

    private func submit(_ cmd: String) {
        let c = cmd.trimmingCharacters(in: .whitespaces)
        guard !c.isEmpty else { return }
        engine.submit(c)
        inputText = ""
        focused   = true
    }
}

// MARK: - Window configurator

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let win = v.window else { return }
            win.isMovableByWindowBackground  = true
            win.titlebarAppearsTransparent   = true
            win.backgroundColor = NSColor(red: 0.027, green: 0.035, blue: 0.055, alpha: 1)
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Header

struct HeaderView: View {
    @ObservedObject var engine: CommandEngine
    @State private var dotScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 80)

            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Mac Control")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(engine.isRunning ? Theme.warning : Theme.success)
                    .frame(width: 7, height: 7)
                    .scaleEffect(engine.isRunning ? dotScale : 1.0)
                    .shadow(
                        color: engine.isRunning
                            ? Theme.warning.opacity(0.8)
                            : Theme.success.opacity(0.5),
                        radius: 4
                    )

                Text(engine.statusText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(engine.statusColor)
            }
            .padding(.trailing, 20)
        }
        .frame(height: 52)
        .background(Theme.surface)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                dotScale = 1.35
            }
        }
    }
}

// MARK: - Chat

struct ChatScrollView: View {
    let messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                    Color.clear.frame(height: 12).id("__end__")
                }
                .padding(.vertical, 12)
            }
            .background(Theme.bg)
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("__end__", anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Input bar

struct InputBarView: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    let isRunning: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Type a command…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.text)
                .focused(focused)
                .onSubmit(onSubmit)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surf3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    focused.wrappedValue ? Theme.accent.opacity(0.55) : Theme.border,
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: focused.wrappedValue ? Theme.accent.opacity(0.18) : .clear,
                            radius: 8
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: focused.wrappedValue)

            Button(action: onSubmit) {
                Image(systemName: isRunning ? "stop.circle.fill" : "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(canSend ? Theme.accent : Theme.muted)
                            .shadow(color: canSend ? Theme.accent.opacity(0.4) : .clear, radius: 6)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.15), value: canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surf2)
    }

    private var canSend: Bool {
        !isRunning && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Suggestions

struct SuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { s in
                        Button(action: { onSelect(s) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.accent.opacity(0.7))
                                Text(s)
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                        .buttonStyle(ChipStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
            }
            .background(Theme.surf2)
            .frame(height: 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Button styles

struct ChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.text : Theme.subtext)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(configuration.isPressed ? Theme.surf3 : Theme.surf3.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
            )
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
