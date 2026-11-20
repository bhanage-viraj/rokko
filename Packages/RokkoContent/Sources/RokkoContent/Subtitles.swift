//
//  Subtitles.swift
//  Content/Lesson1/Subtitles/<clip>.subtitles.json: the timed lines of one film clip.
//  Times are "mm:ss.mmm", relative to the clip's own start. One cue shows at a time.
//

import Foundation

public struct Subtitles: Decodable, Sendable, Equatable {
    public struct Cue: Decodable, Sendable, Equatable {
        /// Seconds from the clip start.
        public let start: Double
        public let end: Double
        public let text: String
        /// When the voice is actually speaking inside this line, as [start, end] pairs in clip
        /// seconds (measured by Tools/subtitle_speech_spans.py). Empty = the whole line.
        public let speech: [[Double]]

        public init(start: Double, end: Double, text: String, speech: [[Double]] = []) {
            self.start = start
            self.end = end
            self.text = text
            self.speech = speech
        }

        enum CodingKeys: String, CodingKey { case start, end, text, speech }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            text = try c.decode(String.self, forKey: .text)
            start = try Self.seconds(c.decode(String.self, forKey: .start), key: .start, in: c)
            end = try Self.seconds(c.decode(String.self, forKey: .end), key: .end, in: c)
            speech = try c.decodeIfPresent([[Double]].self, forKey: .speech) ?? []
        }

        /// How many characters of `text` are on screen at `time` (clip seconds).
        /// A speaker tag (`King Sunny: "`) shows at once; then each word appears as the voice
        /// reaches it, spread over the speech stretches only, so words wait through the pauses.
        public func shownCharacters(at time: Double) -> Int {
            let chars = Array(text)
            let lead = speakerTagLength
            guard chars.count > lead else { return chars.count }
            // Share of this line's speech said so far.
            let spans = speech.filter { $0.count == 2 && $0[1] > $0[0] }
            let stretches = spans.isEmpty ? [[start, end]] : spans
            let total = stretches.reduce(0) { $0 + ($1[1] - $1[0]) }
            let said = stretches.reduce(0) { $0 + min(max(time - $1[0], 0), $1[1] - $1[0]) }
            let share = total > 0 ? said / total : 1
            if share >= 1 { return chars.count }
            // A word appears once the voice has reached its first letter.
            let reached = lead + Int((share * Double(chars.count - lead)).rounded(.down))
            var shown = lead
            var i = lead
            while i < chars.count {
                while i < chars.count, chars[i] == " " { i += 1 }
                guard i < chars.count, i <= reached else { break }
                while i < chars.count, chars[i] != " " { i += 1 }
                shown = i
            }
            return shown
        }

        /// `Name: "` at the start of a character's line (not spoken, so not timed).
        var speakerTagLength: Int {
            guard let colon = text.range(of: ": \""),
                  !text[text.startIndex..<colon.lowerBound].contains("\"") else { return 0 }
            return text.distance(from: text.startIndex, to: colon.upperBound)
        }

        private static func seconds(_ s: String, key: CodingKeys,
                                    in c: KeyedDecodingContainer<CodingKeys>) throws -> Double {
            guard let t = Subtitles.parseTime(s) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: c,
                                                       debugDescription: "Time \"\(s)\" is not mm:ss.mmm")
            }
            return t
        }
    }

    /// Clip id from manifest.json.
    public let clip: String
    /// In time order, never overlapping.
    public let cues: [Cue]

    public init(clip: String, cues: [Cue]) {
        self.clip = clip
        self.cues = cues
    }

    public static func load(from url: URL) throws -> Subtitles {
        try JSONDecoder().decode(Subtitles.self, from: Data(contentsOf: url))
    }

    /// The line on screen at `time` (seconds from the clip start), or nil between lines.
    public func cue(at time: Double) -> Cue? {
        cues.last { $0.start <= time && time < $0.end }
    }

    /// "mm:ss.mmm" (or "hh:mm:ss.mmm") → seconds. Also accepts the SRT comma ("00:04,800").
    public static func parseTime(_ s: String) -> Double? {
        let parts = s.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard (2...3).contains(parts.count), let secs = Double(parts.last!), secs >= 0, secs < 60 else { return nil }
        var total = secs
        for (i, part) in parts.dropLast().reversed().enumerated() {
            guard let n = Int(part), n >= 0 else { return nil }
            total += Double(n) * (i == 0 ? 60 : 3600)
        }
        return total
    }
}
