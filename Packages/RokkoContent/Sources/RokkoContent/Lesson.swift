//
//  Lesson.swift
//  Content/Lesson1/lesson1.json: the lesson as a list of steps (docs/ARCHITECTURE.md › Step kinds).
//  The coordinator only knows step kinds; Lesson 2 is a new file of the same shape.
//

import Foundation

public struct Lesson: Decodable, Sendable {
    public let lesson: Int
    public let title: String
    public let steps: [LessonStep]
    /// Steps the engine inserts once (the charcoal intro before the first level-5 round).
    public let inserted: [String: LessonStep]

    public static func load(from url: URL) throws -> Lesson {
        try JSONDecoder().decode(Lesson.self, from: Data(contentsOf: url))
    }

    public func index(of stepId: String) -> Int? { steps.firstIndex { $0.id == stepId } }
}

public enum StepKind: String, Decodable, Sendable {
    case film, meet, transform, guardianShow, guardianModule, gameBlock, charcoalIntro
    case `break`, playTogether, complete
}

public struct LessonStep: Decodable, Sendable, Identifiable {
    public let id: String
    public let kind: StepKind
    /// Video clip id from manifest.json (film, transform, charcoalIntro).
    public let clip: String?
    /// Character key (meet).
    public let animal: String?
    /// Voice keys said on this step, in order (a single string in the JSON is one key).
    public let voice: [String]
    /// Again replays the clip (transform).
    public let again: Bool
    /// The piece (guardianShow) or pieces (guardianModule).
    public let piece: Piece?
    public let pieces: [Piece]
    /// guardianShow: show the numbered steps here even in one-line tips mode (first visit).
    public let firstVisitSteps: Bool
    /// gameBlock
    public let module: Int?
    public let intro: String?
    /// gameBlock: the EngineConfig › gates entry that ends the block.
    public let gate: String?
    /// gameBlock: `{ "charcoalIntro": "<inserted step key>" }`.
    public let insertsOnce: [String: String]
    /// break: the planned break (true) or one the Guardian asked for.
    public let planned: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, clip, animal, voice, again, piece, pieces, firstVisitSteps, module, intro, gate, insertsOnce, planned
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(StepKind.self, forKey: .kind)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? kind.rawValue
        clip = try c.decodeIfPresent(String.self, forKey: .clip)
        animal = try c.decodeIfPresent(String.self, forKey: .animal)
        if let one = try? c.decodeIfPresent(String.self, forKey: .voice) {
            voice = [one]
        } else {
            voice = try c.decodeIfPresent([String].self, forKey: .voice) ?? []
        }
        again = try c.decodeIfPresent(Bool.self, forKey: .again) ?? false
        piece = try c.decodeIfPresent(Piece.self, forKey: .piece)
        pieces = try c.decodeIfPresent([Piece].self, forKey: .pieces) ?? []
        firstVisitSteps = try c.decodeIfPresent(Bool.self, forKey: .firstVisitSteps) ?? false
        module = try c.decodeIfPresent(Int.self, forKey: .module)
        intro = try c.decodeIfPresent(String.self, forKey: .intro)
        gate = try c.decodeIfPresent(String.self, forKey: .gate)
        insertsOnce = try c.decodeIfPresent([String: String].self, forKey: .insertsOnce) ?? [:]
        planned = try c.decodeIfPresent(Bool.self, forKey: .planned) ?? false
    }
}

/// Content/Lesson1/manifest.json: the video files the video team delivers.
public struct ClipManifest: Decodable, Sendable {
    public struct Clip: Decodable, Sendable {
        public let id: String
        public let files: [String: String]
        public let seconds: Double?
        /// Subtitle file (Content/Lesson1/Subtitles/), for clips with narration.
        public let subtitles: String?
        /// Seconds into the clip of its last bright frame (before the fade), held once it has ended.
        public let endStill: Double?
    }
    public let clips: [Clip]

    public static func load(from url: URL) throws -> ClipManifest {
        try JSONDecoder().decode(ClipManifest.self, from: Data(contentsOf: url))
    }

    public func clip(_ id: String) -> Clip? { clips.first { $0.id == id } }
}
