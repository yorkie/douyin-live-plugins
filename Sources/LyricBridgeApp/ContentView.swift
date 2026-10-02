import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    trackSection
                    lyricSection
                    settingsSection
                }
                .padding(24)
            }
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.50, green: 0.29, blue: 0.95))
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("LYRIC BRIDGE").font(.system(size: 13, weight: .bold, design: .rounded)).tracking(1.2)
                Text("网易云歌词 · 抖音直播伴侣").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(model.snapshot?.isPlaying == true ? Color.green : Color.orange).frame(width: 7, height: 7)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionLabel(model.hasAccessibilityPermission ? "正在播放" : "需要授权",
                         trailing: model.snapshot.map { timeString($0.position) + " / " + timeString($0.duration) } ?? "网易云音乐")
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(colors: [Color(red: 0.45, green: 0.25, blue: 0.8), Color(red: 0.2, green: 0.17, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "music.note").font(.system(size: 19, weight: .medium)).foregroundStyle(.white.opacity(0.85)))
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.snapshot?.title ?? (model.hasAccessibilityPermission ? "等待网易云音乐播放" : "开启辅助功能权限以识别歌曲"))
                        .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                    Text(model.snapshot?.artist ?? (model.hasAccessibilityPermission ? "网易云打开并播放后会自动识别" : "前往系统设置允许 Lyric Bridge 读取播放信息"))
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if model.snapshot?.isPlaying == true {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.purple.opacity(0.9))
                }
            }
            if let snapshot = model.snapshot {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(Color.purple).frame(width: proxy.size.width * min(snapshot.position / max(snapshot.duration, 1), 1))
                    }
                }.frame(height: 3)
            }
            if !model.candidates.isEmpty && model.candidates.count > 1 {
                Menu {
                    ForEach(model.candidates) { candidate in
                        Button("\(candidate.name) — \(candidate.artistNames)") { model.choose(candidate) }
                    }
                } label: {
                    Label("选择匹配版本", systemImage: "chevron.down.circle")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }.menuStyle(.borderlessButton)
            }
        }
    }

    private var lyricSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("歌词预览", trailing: model.lines.isEmpty ? "暂无歌词" : "\(model.lines.count) 行")
            VStack(alignment: .leading, spacing: 10) {
                Text(model.currentLyric?.text ?? "歌词将在这里同步显示")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundColor(model.currentLyric == nil ? Color.secondary : Color.white)
                    .lineLimit(2)
                    .contentTransition(.opacity)
                if let translation = model.currentLyric?.translation, model.showTranslation {
                    Text(translation).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(model.status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(model.hasAccessibilityPermission ? Color.secondary : Color.orange)
                    .padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            sectionLabel("显示设置")
            HStack {
                Label("同步微调", systemImage: "clock.arrow.circlepath").font(.system(size: 12))
                Slider(value: $model.offset, in: -5...5, step: 0.1)
                Text(String(format: "%+.1fs", model.offset)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
            }
            HStack {
                Label("歌词字号", systemImage: "textformat.size").font(.system(size: 12))
                Slider(value: $model.fontSize, in: 24...56, step: 1)
                Text("\(Int(model.fontSize))").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
            }
            Toggle(isOn: $model.showTranslation) {
                Label("显示翻译歌词", systemImage: "character.bubble").font(.system(size: 12))
            }.toggleStyle(.switch).controlSize(.small)
            if !model.hasAccessibilityPermission {
                HStack {
                Text("需要 macOS 辅助功能权限读取网易云歌曲与进度")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("前往授权") { model.openAccessibilitySettings() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 9) {
            Button { model.importLRC() } label: { Label("导入 LRC", systemImage: "doc.badge.plus") }
                .buttonStyle(.bordered).controlSize(.regular)
            Button { model.toggleOverlay() } label: {
                Label(model.overlayVisible ? "隐藏歌词窗" : "打开歌词窗", systemImage: model.overlayVisible ? "eye.slash" : "rectangle.on.rectangle")
            }
            .buttonStyle(.borderedProminent).tint(Color(red: 0.48, green: 0.29, blue: 0.92)).controlSize(.regular)
            Spacer()
            Image(systemName: "macwindow.on.rectangle").foregroundStyle(.secondary)
                .help("在抖音直播伴侣中添加窗口捕获，选择 Lyric Bridge")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }

    private func sectionLabel(_ title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1.1).foregroundStyle(.secondary)
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.tertiary) }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        String(format: "%d:%02d", Int(time) / 60, Int(time) % 60)
    }
}
