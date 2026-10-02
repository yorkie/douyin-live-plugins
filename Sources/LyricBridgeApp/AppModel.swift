import AppKit
import ApplicationServices
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot: PlayerSnapshot?
    @Published var candidates: [TrackCandidate] = []
    @Published var selectedCandidate: TrackCandidate?
    @Published var lines: [LyricLine] = []
    @Published var currentLyric: LyricLine?
    @Published var status = "连接网易云音乐中…"
    @Published var hasAccessibilityPermission = false
    @Published var overlayVisible = true
    @Published var offset: Double = 0
    @Published var fontSize: Double = 38
    @Published var showTranslation = true

    private let reader = AccessibilityPlayerReader()
    private let lyricsService = NetEaseLyricsService()
    private var overlay: OverlayController!
    private var pollTask: Task<Void, Never>?
    private var lastTrackKey = ""
    private var lastPosition: TimeInterval = 0
    private var lastTick = Date()
    private var cuePosition: TimeInterval = 0
    private var cueDate = Date()
    private var consecutiveMisses = 0
    private var readerErrorIsDisplayed = false

    init() { overlay = OverlayController(model: self) }

    func start() {
        guard pollTask == nil else { return }
        overlay.show()
        pollTask = Task {
            while !Task.isCancelled {
                poll()
                try? await Task.sleep(for: .milliseconds(450))
            }
        }
    }

    func toggleOverlay() {
        overlayVisible.toggle()
        if overlayVisible { overlay.show() } else { overlay.hide() }
    }

    func playNextTrack() {
        guard hasAccessibilityPermission else {
            status = "需要辅助功能权限才能控制网易云音乐"
            return
        }
        status = reader.playNextTrack() ? "已切换到下一首" : "未找到网易云音乐的下一首按钮"
    }

    func choose(_ candidate: TrackCandidate) {
        selectedCandidate = candidate
        Task { await loadLyrics(for: candidate) }
    }

    func importLRC() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.message = "选择 .lrc 歌词文件"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            lines = LRCParser.parse(content)
            selectedCandidate = nil
            status = lines.isEmpty ? "没有读取到带时间戳的歌词" : "已载入本地歌词"
            updateCurrentLyric(at: estimatedPosition())
        } catch { status = "无法读取歌词文件：\(error.localizedDescription)" }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func poll() {
        hasAccessibilityPermission = reader.hasPermission
        guard hasAccessibilityPermission else {
            status = "尚未授权：请在系统设置的辅助功能列表中允许 Lyric Bridge"
            return
        }
        let result = reader.read()
        guard case .snapshot(let next) = result else {
            consecutiveMisses += 1
            var readerError = "网易云窗口暂时无法读取播放信息"
            switch result {
            case .applicationNotRunning:
                readerError = "已授权，但没有找到网易云音乐进程"
            case .windowNotAvailable:
                readerError = "已找到网易云，但暂时无法读取它的窗口"
            case .playerFieldsNotFound:
                readerError = "已找到网易云窗口，但未读到歌曲与进度信息"
            case .snapshot:
                break
            }
            if consecutiveMisses >= 5 {
                snapshot = nil
                lines = []
                currentLyric = nil
                candidates = []
                selectedCandidate = nil
                lastTrackKey = ""
                status = readerError
                readerErrorIsDisplayed = true
            }
            return
        }
        consecutiveMisses = 0
        let key = "\(next.title)|\(next.artist)"
        if key != lastTrackKey {
            readerErrorIsDisplayed = false
            lastTrackKey = key
            snapshot = next
            lastPosition = next.position
            lastTick = Date()
            cuePosition = next.position
            cueDate = Date()
            lines = []
            currentLyric = nil
            selectedCandidate = nil
            status = "正在匹配网易云歌词…"
            Task { await findLyrics(for: next) }
        } else {
            snapshot = next
            if readerErrorIsDisplayed {
                status = lines.isEmpty ? "正在匹配网易云歌词…" : "歌词已同步 · 网易云音乐"
                readerErrorIsDisplayed = false
            }
            if next.position + 2 < lastPosition || abs(next.position - lastPosition) > 4 {
                cuePosition = next.position
                cueDate = Date()
            }
            lastPosition = next.position
            lastTick = Date()
            updateCurrentLyric(at: estimatedPosition())
        }
    }

    private func estimatedPosition() -> TimeInterval {
        let base = snapshot?.position ?? cuePosition
        let isPlaying = snapshot?.isPlaying ?? false
        let estimate = base + (isPlaying ? Date().timeIntervalSince(lastTick) : 0) + offset
        return max(0, min(snapshot?.duration ?? .greatestFiniteMagnitude, estimate))
    }

    private func findLyrics(for snapshot: PlayerSnapshot) async {
        do {
            let matches = try await lyricsService.search(title: snapshot.title, artist: snapshot.artist)
            guard lastTrackKey == "\(snapshot.title)|\(snapshot.artist)" else { return }
            candidates = matches
            guard let best = matches.first else { status = "没有找到匹配歌曲，可导入 LRC"; return }
            choose(best)
        } catch { status = "在线匹配失败，可检查网络或导入 LRC" }
    }

    private func loadLyrics(for candidate: TrackCandidate) async {
        do {
            let loaded = try await lyricsService.lyrics(for: candidate)
            guard selectedCandidate?.id == candidate.id else { return }
            lines = loaded
            status = loaded.isEmpty ? "这首歌暂无同步歌词，可导入 LRC" : "歌词已同步 · 网易云音乐"
            cuePosition = snapshot?.position ?? 0
            cueDate = Date()
            lastTick = Date()
            updateCurrentLyric(at: estimatedPosition())
        } catch { status = "\(error.localizedDescription)，可导入 LRC" }
    }

    private func updateCurrentLyric(at position: TimeInterval) {
        currentLyric = lines.last(where: { $0.time <= position })
    }
}
