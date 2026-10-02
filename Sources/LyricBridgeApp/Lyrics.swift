import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let time: TimeInterval
    let text: String
    let translation: String?
}

struct TrackCandidate: Identifiable, Equatable, Decodable, Sendable {
    let id: Int
    let name: String
    let artists: [Artist]
    let album: Album?

    struct Artist: Decodable, Equatable, Sendable {
        let name: String
    }
    struct Album: Decodable, Equatable, Sendable {
        let name: String
        enum CodingKeys: String, CodingKey { case name = "name" }
    }

    var artistNames: String { artists.map(\.name).joined(separator: " / ") }
    var subtitle: String { "\(artistNames) · \(album?.name ?? "网易云音乐")" }
}

enum LRCParser {
    private static let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)"#

    static func parse(_ lyric: String, translation: String? = nil) -> [LyricLine] {
        let original = parseRaw(lyric)
        let translated = translation.map(parseRaw) ?? []
        return original.enumerated().map { index, row in
            let nearby = translated.last(where: { $0.time <= row.time + 0.15 })
            return LyricLine(id: index, time: row.time, text: row.text,
                             translation: nearby?.text.isEmpty == false ? nearby?.text : nil)
        }.filter { !$0.text.isEmpty }
    }

    private static func parseRaw(_ source: String) -> [(time: TimeInterval, text: String)] {
        let regex = try? NSRegularExpression(pattern: pattern)
        return source.components(separatedBy: .newlines).compactMap { line in
            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex?.firstMatch(in: line, range: range),
                  let minuteRange = Range(match.range(at: 1), in: line),
                  let secondRange = Range(match.range(at: 2), in: line),
                  let textRange = Range(match.range(at: 4), in: line),
                  let minutes = Double(line[minuteRange]),
                  let seconds = Double(line[secondRange]) else { return nil }
            var fraction: Double = 0
            if let fractionRange = Range(match.range(at: 3), in: line) {
                let digits = String(line[fractionRange])
                fraction = (Double(digits) ?? 0) / pow(10, Double(digits.count))
            }
            return (minutes * 60 + seconds + fraction, String(line[textRange]).trimmingCharacters(in: .whitespaces))
        }.sorted { $0.time < $1.time }
    }
}
