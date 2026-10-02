import AppKit
import SwiftUI

@MainActor
final class OverlayController {
    private var window: NSWindow?
    private let model: AppModel

    init(model: AppModel) { self.model = model }

    func show() {
        if let window { window.orderFrontRegardless(); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 116),
                              styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.title = "Lyric Bridge — 歌词"
        window.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.047, blue: 0.078, alpha: 1)
        window.isOpaque = true
        window.hasShadow = false
        window.alphaValue = 1
        window.isMovableByWindowBackground = true
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        let hostingView = NSHostingView(rootView: LyricOverlayView().environmentObject(model))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = window.backgroundColor?.cgColor
        window.contentView = hostingView
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        window.setFrameOrigin(NSPoint(x: screen.midX - 380, y: screen.minY + 90))
        self.window = window
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}

struct LyricOverlayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.62, green: 0.39, blue: 1))
                .frame(width: 4, height: 52)

            VStack(alignment: .leading, spacing: 7) {
                Text(model.currentLyric?.text ?? "等待歌词…")
                    .font(.system(size: model.fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                if let translation = model.currentLyric?.translation, model.showTranslation {
                    Text(translation)
                        .font(.system(size: max(15, model.fontSize * 0.48), weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(action: model.playNextTrack) {
                Label("下一首", systemImage: "forward.end.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.42, green: 0.25, blue: 0.78), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)
            .help("切换网易云音乐到下一首")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 25)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.085, green: 0.069, blue: 0.13),
                    Color(red: 0.055, green: 0.047, blue: 0.078)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .ignoresSafeArea()
    }
}
