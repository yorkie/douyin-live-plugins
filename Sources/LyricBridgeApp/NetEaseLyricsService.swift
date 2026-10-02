import Foundation

actor NetEaseLyricsService {
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()

    private struct SearchResponse: Decodable {
        struct Result: Decodable { let songs: [TrackCandidate]? }
        let result: Result?
    }
    private struct LyricResponse: Decodable {
        struct Payload: Decodable { let lyric: String? }
        let lrc: Payload?
        let tlyric: Payload?
    }

    func search(title: String, artist: String) async throws -> [TrackCandidate] {
        var components = URLComponents(string: "https://music.163.com/api/search/get")!
        components.queryItems = [
            URLQueryItem(name: "s", value: "\(title) \(artist)"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "8"),
            URLQueryItem(name: "offset", value: "0")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("LyricBridge/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.unavailable }
        let results = try JSONDecoder().decode(SearchResponse.self, from: data).result?.songs ?? []
        return results.sorted { score($0, title: title, artist: artist) > score($1, title: title, artist: artist) }
    }

    func lyrics(for track: TrackCandidate) async throws -> [LyricLine] {
        var components = URLComponents(string: "https://music.163.com/api/song/lyric")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(track.id)),
            URLQueryItem(name: "lv", value: "1"),
            URLQueryItem(name: "kv", value: "1"),
            URLQueryItem(name: "tv", value: "-1")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue("LyricBridge/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ServiceError.unavailable }
        let payload = try JSONDecoder().decode(LyricResponse.self, from: data)
        guard let lyric = payload.lrc?.lyric, !lyric.isEmpty else { throw ServiceError.noLyrics }
        return LRCParser.parse(lyric, translation: payload.tlyric?.lyric)
    }

    private func score(_ candidate: TrackCandidate, title: String, artist: String) -> Int {
        let normalize: (String) -> String = { $0.lowercased().filter { $0.isLetter || $0.isNumber } }
        let titleScore = normalize(candidate.name) == normalize(title) ? 4 :
            (normalize(candidate.name).contains(normalize(title)) ? 2 : 0)
        let artistScore = candidate.artists.contains { normalize($0.name) == normalize(artist) } ? 3 :
            (candidate.artists.contains { normalize($0.name).contains(normalize(artist)) } ? 1 : 0)
        return titleScore + artistScore
    }

    enum ServiceError: LocalizedError {
        case unavailable, noLyrics
        var errorDescription: String? {
            switch self {
            case .unavailable: "网易云音乐服务暂时不可用"
            case .noLyrics: "这首歌暂时没有可用歌词"
            }
        }
    }
}
