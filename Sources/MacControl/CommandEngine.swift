import Foundation
import AppKit
import SwiftUI
import Darwin
import ApplicationServices

// MARK: - Internal types

private struct ParsedCommand {
    var action: String?
    var target: String?
    var value: Int?
    var correctedFrom: String?
}

private struct CommandResult {
    var output: [String]
    var shouldExit: Bool
    var newAppIndex: [String: String]?
    var newNormIndex: [String: String]?
}

// MARK: - Engine

final class CommandEngine: ObservableObject {
    @Published var messages:    [Message] = []
    @Published var suggestions: [String]  = []
    @Published var isRunning              = false
    @Published var statusText             = "● starting…"
    @Published var statusColor: Color     = Theme.muted

    private var appIndex:  [String: String] = [:]  // displayName → path
    private var normIndex: [String: String] = [:]  // normalized  → displayName

    private let knownActions = [
        "open", "close", "volume", "brightness",
        "mute", "unmute", "lock", "sleep",
        "help", "list", "refresh", "permissions", "exit", "quit",
    ]
    private let mediaSteps      = 16
    private let brightnessDown  = 144
    private let brightnessUp    = 145
    private let volumeUp        = 72
    private let volumeDown      = 73
    private let volumeMute      = 74

    // MARK: Boot

    func boot() {
        setStatus("● scanning…", Theme.muted)
        push("Mac", "Scanning installed applications…", isUser: false)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let (idx, nIdx) = Self.scanApps()
            DispatchQueue.main.async {
                self.appIndex  = idx
                self.normIndex = nIdx
                self.push("Mac",
                    "Indexed \(idx.count) apps.  Type help to see commands.",
                    isUser: false)
                self.setStatus("● \(idx.count) apps", Theme.success)
                self.updateSuggestions(for: "")
            }
        }
    }

    // MARK: Submit

    func submit(_ raw: String) {
        let cmd = raw.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty else { return }

        push("You", cmd, isUser: true)
        isRunning = true
        setStatus("● running…", Theme.muted)
        updateSuggestions(for: "")

        let snap    = appIndex
        let snapN   = normIndex

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.run(cmd, appIdx: snap, normIdx: snapN)
            DispatchQueue.main.async {
                if let ni = result.newAppIndex, let nn = result.newNormIndex {
                    self.appIndex  = ni
                    self.normIndex = nn
                }
                if !result.output.isEmpty {
                    self.push("Mac", result.output.joined(separator: "\n"), isUser: false)
                }
                self.isRunning = false
                self.setStatus("● \(self.appIndex.count) apps", Theme.success)
                if result.shouldExit { NSApp.terminate(nil) }
            }
        }
    }

    // MARK: Suggestions

    func updateSuggestions(for text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else {
            suggestions = ["help", "list", "open Safari", "close Safari", "volume 50", "lock"]
            return
        }
        let parts  = t.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let action = parts[0].lowercased()

        if parts.count == 1 {
            let byContains = knownActions.filter { $0.contains(action) }
            let byApps = appIndex.keys
                .sorted { $0.lowercased() < $1.lowercased() }
                .filter { $0.lowercased().contains(action) }
                .prefix(6)
                .flatMap { ["open \($0)", "close \($0)"] }

            var seen = Set<String>()
            suggestions = (byContains + byApps).filter { seen.insert($0).inserted }
            return
        }
        if action == "open" || action == "close" {
            let query   = parts.dropFirst().joined(separator: " ").lowercased()
            let names   = appIndex.keys.sorted { $0.lowercased() < $1.lowercased() }
            let matched = query.isEmpty ? Array(names.prefix(9))
                                        : names.filter { $0.lowercased().contains(query) }.prefix(9).map { $0 }
            suggestions = matched.map { "\(action) \($0)" }
            return
        }
        if action == "volume" || action == "brightness" {
            suggestions = ["\(action) 50", "\(action) up 10", "\(action) down 10"]
            return
        }
        suggestions = []
    }

    // MARK: - Execution (background thread)

    private func run(_ line: String,
                     appIdx:  [String: String],
                     normIdx: [String: String]) -> CommandResult
    {
        let parsed = parseInput(line)
        var out: [String] = []

        guard let action = parsed.action else {
            if let c = parsed.correctedFrom {
                out.append("✗ Command not recognized: \"\(c)\". Try: help")
            }
            return CommandResult(output: out, shouldExit: false)
        }

        if parsed.correctedFrom != nil { out.append("→ Recognized as: \(action)") }

        switch action {
        case "exit", "quit":
            return CommandResult(output: [], shouldExit: true)

        case "help":
            out.append(contentsOf: helpLines())

        case "list":
            let names = appIdx.keys.sorted { $0.lowercased() < $1.lowercased() }
            out.append(contentsOf: names.isEmpty ? ["No applications indexed."] : names)

        case "refresh":
            out.append("→ Refreshing index…")
            let (newIdx, newNIdx) = Self.scanApps()
            out.append("✓ Done. \(newIdx.count) applications found.")
            return CommandResult(output: out, shouldExit: false,
                                 newAppIndex: newIdx, newNormIndex: newNIdx)

        case "permissions":
            let (ok, lines) = requestPermissions()
            out.append(contentsOf: lines)
            if ok { out.append("✓ Permissions look good.") }

        case "volume":
            guard let target = parsed.target, let value = parsed.value else {
                out.append("! Usage: volume <0-100>  or  volume up/down [step]"); break
            }
            let (ok, msg) = target == "set" ? setVolumeAbsolute(value)
                                            : changeVolume(direction: target, step: value)
            out.append(ok ? "✓ Volume \(target == "set" ? "→ \(max(0,min(100,value)))" : "\(target) ~\(value)%")"
                          : "✗ \(msg)")

        case "brightness":
            guard let target = parsed.target, let value = parsed.value else {
                out.append("! Usage: brightness <0-100>  or  brightness up/down [step]"); break
            }
            let (ok, msg) = target == "set" ? setBrightnessAbsolute(value)
                                            : changeBrightness(direction: target, step: value)
            out.append(ok ? "✓ Brightness \(target == "set" ? "→ \(max(0,min(100,value)))%" : "\(target) ~\(value)%")"
                          : "✗ \(msg)")

        case "mute":
            let (ok, msg) = toggleMute(true);  out.append(ok ? "✓ Output muted."   : "✗ \(msg)")
        case "unmute":
            let (ok, msg) = toggleMute(false); out.append(ok ? "✓ Output unmuted." : "✗ \(msg)")

        case "lock":
            let (ok, msg) = lockScreen();   out.append(ok ? "✓ Screen locked."     : "✗ \(msg)")
        case "sleep":
            let (ok, msg) = sleepDisplay(); out.append(ok ? "✓ Display sleep sent." : "✗ \(msg)")

        case "open", "close":
            guard let target = parsed.target else { out.append("! Usage: \(action) <app>"); break }
            guard let name = Self.findMatch(for: target, appIdx: appIdx, normIdx: normIdx) else {
                out.append("✗ Application not found: \"\(target)\""); break
            }
            if Self.norm(target) != Self.norm(name) { out.append("→ Recognized as: \(name)") }

            if action == "open" {
                guard let path = appIdx[name] else { out.append("✗ No path for \(name)."); break }
                let (ok, msg) = shell("/usr/bin/open", [path])
                out.append(ok ? "✓ Opened: \(name)" : "✗ \(msg)")
            } else {
                let (ok, _) = shell("/usr/bin/osascript",
                                    ["-e", "tell application \"\(name)\" to quit"])
                if ok { out.append("✓ Closed: \(name)") }
                else {
                    let (ok2, msg2) = shell("/usr/bin/killall", [name])
                    out.append(ok2 ? "✓ Closed: \(name)" : "✗ \(msg2)")
                }
            }

        default: break
        }

        return CommandResult(output: out, shouldExit: false)
    }

    // MARK: - Parsing

    private func parseInput(_ line: String) -> ParsedCommand {
        let parts = line.trimmingCharacters(in: .whitespaces)
            .split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !parts.isEmpty else { return ParsedCommand() }

        let (action, corrected) = parseAction(parts[0])
        guard let action else { return ParsedCommand(correctedFrom: corrected ?? parts[0]) }

        let noTarget: Set<String> = ["exit","quit","help","list","refresh","permissions",
                                     "mute","unmute","lock","sleep"]
        if noTarget.contains(action) { return ParsedCommand(action: action, correctedFrom: corrected) }

        if action == "volume" || action == "brightness" {
            guard parts.count >= 2 else { return ParsedCommand(action: action, correctedFrom: corrected) }
            let mode = parts[1].lowercased()
            if mode == "up" || mode == "down" {
                let step = parts.count >= 3 ? Int(parts[2]) ?? 10 : 10
                return ParsedCommand(action: action, target: mode, value: step, correctedFrom: corrected)
            }
            if let v = Int(parts[1]) {
                return ParsedCommand(action: action, target: "set", value: v, correctedFrom: corrected)
            }
            return ParsedCommand(action: action, correctedFrom: corrected)
        }

        let target = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil
        return ParsedCommand(action: action, target: target, correctedFrom: corrected)
    }

    private func parseAction(_ raw: String) -> (String?, String?) {
        let a = raw.lowercased()
        if knownActions.contains(a) { return (a, nil) }
        var best: String?; var bestScore = 0.6
        for k in knownActions { let s = Self.sim(a, k); if s > bestScore { bestScore = s; best = k } }
        return (best, best != nil ? a : nil)
    }

    // MARK: - App scanning

    static func scanApps() -> ([String: String], [String: String]) {
        var idx: [String: String] = [:]
        var nIdx: [String: String] = [:]
        let dirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications"),
        ]
        for dir in dirs {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            guard let e = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsPackageDescendants
            ) else { continue }
            for case let url as URL in e where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                if idx[name] == nil { idx[name] = url.path; nIdx[norm(name)] = name }
            }
        }
        return (idx, nIdx)
    }

    static func findMatch(for raw: String,
                          appIdx:  [String: String],
                          normIdx: [String: String]) -> String?
    {
        let c = raw.trimmingCharacters(in: .whitespaces)
        if appIdx[c] != nil { return c }
        let n = norm(c)
        if let m = normIdx[n] { return m }
        var best: String?; var bestScore = 0.5
        for (k, v) in normIdx { let s = sim(n, k); if s > bestScore { bestScore = s; best = v } }
        return best
    }

    // MARK: - Shell helpers

    @discardableResult
    private func shell(_ exec: String, _ args: [String]) -> (Bool, String) {
        let p = Process(); let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = pipe
        p.executableURL  = URL(fileURLWithPath: exec)
        p.arguments      = args
        do {
            try p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out  = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (p.terminationStatus == 0, out)
        } catch { return (false, error.localizedDescription) }
    }

    private func osascript(_ s: String) -> (Bool, String) {
        shell("/usr/bin/osascript", ["-e", s])
    }

    private func keyCode(_ code: Int, times: Int = 1) -> (Bool, String) {
        let (permitted, lines) = requestPermissions()
        if !permitted {
            return (false, lines.joined(separator: " "))
        }
        let t = max(1, min(50, times))
        return osascript("""
            tell application "System Events"
              repeat \(t) times
                key code \(code)
              end repeat
            end tell
            """)
    }

    // MARK: - Commands

    private func setVolumeAbsolute(_ v: Int) -> (Bool, String) {
        let clamped = max(0, min(100, v))
        let (ok, msg) = osascript("set volume output volume \(clamped)")
        if ok { return (true, msg) }
        let steps = Int(Double(clamped) / 100 * Double(mediaSteps))
        let (dn, dm) = keyCode(volumeDown, times: mediaSteps)
        if !dn { return (false, dm) }
        if steps == 0 { return (true, "") }
        return keyCode(volumeUp, times: steps)
    }

    private func changeVolume(direction: String, step: Int) -> (Bool, String) {
        let n = max(1, Int((Double(max(1,step)) / (100.0 / Double(mediaSteps))).rounded()))
        return keyCode(direction == "up" ? volumeUp : volumeDown, times: n)
    }

    private func setBrightnessAbsolute(_ v: Int) -> (Bool, String) {
        let steps = Int(Double(max(0,min(100,v))) / 100 * Double(mediaSteps))
        let (dn, dm) = keyCode(brightnessDown, times: mediaSteps)
        if !dn { return (false, dm) }
        if steps == 0 { return (true, "") }
        return keyCode(brightnessUp, times: steps)
    }

    private func changeBrightness(direction: String, step: Int) -> (Bool, String) {
        let n = max(1, Int((Double(max(1,step)) / (100.0 / Double(mediaSteps))).rounded()))
        return keyCode(direction == "up" ? brightnessUp : brightnessDown, times: n)
    }

    private func getMuteState() -> (Bool, Bool?, String) {
        let (ok, msg) = osascript("output muted of (get volume settings)")
        if !ok { return (false, nil, msg) }

        let normalized = msg.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "true":
            return (true, true, "")
        case "false":
            return (true, false, "")
        default:
            return (false, nil, "Unexpected mute state: \(msg)")
        }
    }

    private func toggleMute(_ muted: Bool) -> (Bool, String) {
        let (stateOK, currentMuted, stateMsg) = getMuteState()
        if stateOK, currentMuted == muted {
            return (true, "")
        }

        let (directOK, directMsg) = osascript("set volume output muted \(muted)")
        if directOK {
            return (true, directMsg)
        }

        let (toggleOK, toggleMsg) = keyCode(volumeMute)
        if !toggleOK {
            return (false, directMsg.isEmpty ? (toggleMsg.isEmpty ? stateMsg : toggleMsg) : directMsg)
        }

        let (verifyOK, verifyMuted, verifyMsg) = getMuteState()
        if verifyOK, verifyMuted == muted {
            return (true, toggleMsg)
        }

        return (false, verifyMsg.isEmpty ? (stateMsg.isEmpty ? "Unable to confirm mute state." : stateMsg) : verifyMsg)
    }

    private func lockScreen() -> (Bool, String) {
        // 1) Most reliable path: login.framework private API.
        let loginFramework = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        if let handle = dlopen(loginFramework, RTLD_NOW),
           let sym = dlsym(handle, "SACLockScreenImmediate") {
            typealias LockFn = @convention(c) () -> Void
            let lockNow = unsafeBitCast(sym, to: LockFn.self)
            lockNow()
            dlclose(handle)
            return (true, "")
        }

        // 2) Fallback: modern loginwindow command.
        let loginwindow = "/System/Library/CoreServices/loginwindow.app/Contents/MacOS/loginwindow"
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: loginwindow) {
            let (ok, msg) = shell(loginwindow, ["-LockScreen"])
            if ok {
                // This command can report success but still do nothing on some systems.
                // Keep trying stronger fallbacks instead of returning a false-positive.
                if !msg.lowercased().contains("usage") { return (true, msg) }
            }
        }

        // 3) Legacy path used on some older installs.
        let legacyCGSession = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if fm.isExecutableFile(atPath: legacyCGSession) {
            let (ok, msg) = shell(legacyCGSession, ["-suspend"])
            if ok { return (true, msg) }
        }

        // 4) Last fallback: simulate Ctrl+Cmd+Q (requires Accessibility + Automation).
        let (permitted, lines) = requestPermissions()
        if !permitted {
            return (false, lines.joined(separator: " "))
        }
        let (ok, msg) = osascript("""
            tell application "System Events"
              key code 12 using {control down, command down}
            end tell
            """)
        if ok { return (true, msg) }

        return (false, "Lock command unavailable. Check Accessibility permissions for the app.")
    }

    private func sleepDisplay() -> (Bool, String) {
        shell("/usr/bin/pmset", ["displaysleepnow"])
    }

    private func helpLines() -> [String] {
        [
            "open <app>               open application",
            "close <app>              close application",
            "volume <0-100>           set volume",
            "volume up [step]         increase volume (default 10)",
            "volume down [step]       decrease volume (default 10)",
            "mute / unmute            toggle audio",
            "brightness <0-100>       set brightness",
            "brightness up [step]     increase brightness",
            "brightness down [step]   decrease brightness",
            "lock                     lock screen",
            "sleep                    sleep display",
            "list                     show all apps",
            "refresh                  rebuild app index",
            "permissions              request/check macOS permissions",
            "help                     show this help",
            "exit                     quit",
        ]
    }

    // MARK: - Permissions

    private func requestPermissions() -> (Bool, [String]) {
        var messages: [String] = []
        var permitted = true

        // Accessibility prompt (used for key events via System Events).
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let axTrusted = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if !axTrusted {
            permitted = false
            messages.append("→ Permission requested: Accessibility (Privacy & Security -> Accessibility).")
        }

        // Automation prompt for System Events.
        let (aeOK, aeMsg) = osascript("tell application \"System Events\" to get name of first process")
        if !aeOK {
            let lower = aeMsg.lowercased()
            if aeMsg.contains("-1743") || lower.contains("not authorized") || lower.contains("not permitted") {
                permitted = false
                messages.append("→ Permission requested: Automation -> System Events.")
            }
        }

        if permitted && messages.isEmpty {
            messages.append("✓ Accessibility and Automation are granted.")
        } else if !permitted {
            messages.append("Allow access in System Settings, then run command again.")
        }

        return (permitted, messages)
    }

    // MARK: - Helpers (main thread)

    private func push(_ sender: String, _ text: String, isUser: Bool) {
        messages.append(Message(sender: sender, text: text, isUser: isUser))
    }

    private func setStatus(_ t: String, _ c: Color) { statusText = t; statusColor = c }

    // MARK: - String utilities

    static func norm(_ s: String) -> String { s.lowercased().filter { $0.isLetter || $0.isNumber } }

    static func sim(_ a: String, _ b: String) -> Double {
        if a == b { return 1 }
        if a.isEmpty || b.isEmpty { return 0 }
        return 1 - Double(lev(a, b)) / Double(max(a.count, b.count))
    }

    static func lev(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        // build 2-row DP
        var prev = Array(0...b.count)
        var curr = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            curr[0] = i
            for j in 1...b.count {
                curr[j] = a[i-1] == b[j-1] ? prev[j-1]
                    : 1 + min(prev[j], curr[j-1], prev[j-1])
            }
            (prev, curr) = (curr, prev)
        }
        return prev[b.count]
    }
}
