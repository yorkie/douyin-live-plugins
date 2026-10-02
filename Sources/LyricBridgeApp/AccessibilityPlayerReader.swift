import AppKit
import ApplicationServices

struct PlayerSnapshot: Equatable {
    let title: String
    let artist: String
    let position: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
}

enum PlayerReadResult {
    case applicationNotRunning
    case windowNotAvailable
    case playerFieldsNotFound
    case snapshot(PlayerSnapshot)
}

@MainActor
final class AccessibilityPlayerReader {
    private let bundleID = "com.netease.163music"
    private var previousPosition: TimeInterval?
    private var lastProgressDate = Date()
    private var cachedFields: CachedFields?
    private var lastTreeScan = Date.distantPast

    private struct CachedFields {
        let heading: AXUIElement
        let progress: AXUIElement
        let duration: AXUIElement
    }

    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    func playNextTrack() -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            return false
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        var elements: [AXUIElement] = []
        collectElements(from: root, depth: 0, into: &elements)

        for element in elements {
            guard stringAttribute(element, kAXRoleAttribute as CFString) == kAXButtonRole as String else { continue }
            let labels = [
                kAXTitleAttribute as CFString,
                kAXDescriptionAttribute as CFString,
                kAXHelpAttribute as CFString,
                kAXIdentifierAttribute as CFString,
                kAXValueAttribute as CFString
            ].compactMap { stringAttribute(element, $0) }
                .joined(separator: " ")
                .lowercased()
            let isNextButton = labels.contains("下一首") || labels.contains("下一曲") ||
                labels.contains("next track") || labels.contains("next song") || labels == "next"
            guard isNextButton else { continue }
            return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
        }
        return false
    }

    func read() -> PlayerReadResult {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            return .applicationNotRunning
        }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement],
              let window = windows.first else { return .windowNotAvailable }

        if cachedFields == nil || Date().timeIntervalSince(lastTreeScan) > 12 {
            cachedFields = scan(window: window)
            lastTreeScan = Date()
        }
        guard let cachedFields,
              let nowPlaying = stringValue(cachedFields.heading),
              let progressText = stringValue(cachedFields.progress),
              let durationText = stringValue(cachedFields.duration),
              let position = parseTime(progressText),
              let duration = parseTime(durationText) else {
            self.cachedFields = nil
            return .playerFieldsNotFound
        }
        guard nowPlaying.contains(" - ") else { return .playerFieldsNotFound }
        let pieces = nowPlaying.components(separatedBy: " - ")
        guard pieces.count >= 2 else { return .playerFieldsNotFound }
        let title = pieces[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = pieces.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
        if let previousPosition, position > previousPosition { lastProgressDate = Date() }
        else if previousPosition == nil { lastProgressDate = Date() }
        self.previousPosition = position
        return .snapshot(PlayerSnapshot(title: title, artist: artist, position: position, duration: duration,
                                        isPlaying: Date().timeIntervalSince(lastProgressDate) < 2.5))
    }

    private func scan(window: AXUIElement) -> CachedFields? {
        var headings: [(String, AXUIElement)] = []
        var staticTexts: [(String, AXUIElement)] = []
        collect(from: window, depth: 0, headings: &headings, staticTexts: &staticTexts)
        guard let heading = headings.last(where: { $0.0.contains(" - ") })?.1 else { return nil }
        let timed = staticTexts.filter { parseTime($0.0) != nil }
        guard timed.count >= 2 else { return nil }
        return CachedFields(heading: heading, progress: timed[timed.count - 2].1, duration: timed[timed.count - 1].1)
    }

    private func collect(from element: AXUIElement, depth: Int, headings: inout [(String, AXUIElement)], staticTexts: inout [(String, AXUIElement)]) {
        guard depth < 40 else { return }
        var roleValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String ?? ""
        if let value = stringAttribute(element, kAXValueAttribute as CFString) ?? stringAttribute(element, kAXTitleAttribute as CFString) {
            if role == kAXHeadingRole as String, !value.isEmpty { headings.append((value, element)) }
            if role == kAXStaticTextRole as String, !value.isEmpty { staticTexts.append((value, element)) }
        }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return }
        for child in children {
            collect(from: child, depth: depth + 1, headings: &headings, staticTexts: &staticTexts)
        }
    }

    private func collectElements(from element: AXUIElement, depth: Int, into elements: inout [AXUIElement]) {
        guard depth < 40, elements.count < 5000 else { return }
        elements.append(element)
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return }
        for child in children {
            collectElements(from: child, depth: depth + 1, into: &elements)
        }
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: CFString) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func stringValue(_ element: AXUIElement) -> String? {
        stringAttribute(element, kAXValueAttribute as CFString) ?? stringAttribute(element, kAXTitleAttribute as CFString)
    }

    private func parseTime(_ text: String) -> TimeInterval? {
        let pattern = #"(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let minRange = Range(match.range(at: 1), in: text),
              let secRange = Range(match.range(at: 2), in: text),
              let minutes = Double(text[minRange]), let seconds = Double(text[secRange]) else { return nil }
        return minutes * 60 + seconds
    }
}
