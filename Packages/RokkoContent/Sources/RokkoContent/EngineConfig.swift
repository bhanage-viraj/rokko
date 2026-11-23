//
//  EngineConfig.swift
//  The parts of Content/EngineConfig.json the games need. Every tuning number lives in that file.
//

import Foundation

public struct EngineConfig: Decodable, Sendable {
    public let version: Int
    public let generator: Generator
    public let layout: Layout
    public let motion: Motion
    public let bkt: BKT
    public let fastTap: FastTap
    public let levels: Levels
    public let hints: Hints
    public let gates: [String: Gate]
    public let planner: Planner
    public let signal: Signal
    public let breaks: Breaks
    public let storage: Storage
    public let story: Story

    /// A module gate: every listed skill at or above `min`.
    public struct Gate: Decodable, Sendable {
        public let skills: [Skill]
        public let min: Double
    }

    public struct Planner: Decodable, Sendable {
        public struct Block: Decodable, Sendable {
            public let minRounds: Int
            /// The block always ends after this many rounds, gate met or not.
            public let maxRounds: Int
            public let maxRoundsPerSitting: Int
        }
        public let reviewEvery: Int
        public let neverSamePieceTwiceInARow: Bool
        public let alternateTypes12: Bool
        public let blocks: [String: Block]
        /// Module 3 order, "TT-EE": Type 3 white, black → Type 4 white, black → Type 5.
        public let module3Cycle: [String]
    }

    /// When the Guardian button glows (ENGINE §6).
    public struct Signal: Decodable, Sendable {
        public let wrongInLast: Int
        public let wrongCount: Int
        public let slowdownRatio: Double
    }

    public struct Breaks: Decodable, Sendable {
        public let minutes: [Int]
        public let defaultMinutes: Int
        public let addMinutes: Int
        public let activities: [String]
    }

    public struct Storage: Decodable, Sendable {
        public let maxSessionEvents: Int
    }

    public struct Story: Decodable, Sendable {
        /// A clip that has not been delivered yet keeps its (blank) slot this long.
        public let clipPlaceholderSeconds: Double
        /// Lines said in a row: each stays this long after it has typed out.
        public let captionHoldMs: Double
        /// Film subtitles: how often the shown line is checked against the clip time.
        public let subtitleTickMs: Double
        /// Voice lines said in a row (hint + question, cheer + line): silence between them.
        public let voiceGapMs: Double
    }

    public struct BKT: Decodable, Sendable {
        public let pL0: Double
        public let transit: Double
        public let slip: Double
        public let slipWobbly: Double
        public let clampMin: Double
        public let clampMax: Double
        public let hint1GuessMultiplier: Double
        public let hint1GuessMax: Double
        public let type5Guess: Double
    }

    public struct FastTap: Decodable, Sendable {
        public let ratio: Double
        public let warmupResponses: Int
        public let rollingWindow: Int
    }

    public struct Levels: Decodable, Sendable {
        public struct Band: Decodable, Sendable {
            public let level: Int
            public let min: Double
        }
        public let bands: [Band]
        public let mastered: Double
        /// Highest level any exercise plays at (levels above it are off).
        public let maxLevel: Int
        public let buffer: Double
        public let maxStepPerRound: Int
        public let wobblyLevelDrop: Int
        public let level5RequiresCharcoalIntro: Bool
        public let level6RequiresColour: Double
    }

    public struct Hints: Decodable, Sendable {
        /// False: no hint ever appears from waiting; only the child's own wrong answers step the ladder,
        /// so hints never pop up while the Guardian is still explaining the game.
        public let idleHints: Bool
        public let idleSeconds: Double
        public let idleSecondsCalmOrWobbly: Double
        /// Wrong answers per target that only get the soft try-again, before the first hint.
        public let freeTries: Int
        /// Input lock while a hint appears, in ms.
        public let lockMs: Double
    }

    public struct Generator: Decodable, Sendable {
        public let seedHash: String
        public let prng: String
        public let avoidSameAnswerSlot: Bool
        /// Type 4 shelves whose figures are in these forms show the whole team of 16; others show one of each.
        public let shelfFullTeamForms: [ItemForm]?
    }

    public struct Layout: Decodable, Sendable {
        public let choiceCardMin: [Double]
        public let choiceCardLevel4: [Double]
        public let dragCardMin: [Double]
        public let snapDistance: Double
        /// Extra touch area around every card the child can tap or drag (pt).
        public let touchSlop: Double
        /// Finger travel before a press on a draggable becomes a drag (pt). Less = a tap (pick up / put down).
        public let dragStartDistance: Double
        public let type5BatchSize: Int
        public let type3Level4Parts: Int
        /// Type 3 one-at-a-time: blur radius and opacity of the animals that are not up yet.
        public let linkWaitingBlur: Double
        public let linkWaitingAlpha: Double
    }

    public struct Motion: Decodable, Sendable {
        public let screenFadeMs: Double
        public let pressMs: Double
        public let correctMs: Double
        public let bouncePt: Double
        public let tryAgainSinkPt: Double
        public let tryAgainMs: Double
        public let dragLiftScale: Double
        /// Drop target under a dragged card grows to this scale (none in Calm / Reduce Motion).
        public let hoverScale: Double
        /// Caption reveal: time between letters (typed out slowly, character by character).
        public let captionCharMs: Double
        /// Type 3 start: how long one "show me" vine takes to grow, how many times it plays, and the wait before it.
        public let linkDemoMs: Double
        public let linkDemoRepeats: Int
        public let linkDemoDelayMs: Double
        public let snapMs: Double
        public let springBackMs: Double
        public let arrowBobPt: Double
        public let arrowBobMs: Double
        public let breatheSeconds: Double
        /// Lesson map scenery: how far each layer moves per lesson swiped, as a share of the swipe.
        /// Far hills and clouds, middle decorations, and the backdrop inside a card's picture
        /// (the card and its character move with the finger, 1.0). None in Calm / Reduce Motion.
        public let homeParallaxFar: Double
        public let homeParallaxMid: Double
        public let homeParallaxCardArt: Double
        /// Lesson step change: the new step slides in over this long, from this share of the screen
        /// width; the clearing behind it pans `stepParallaxBackground` of that distance (depth).
        /// Calm / Reduce Motion: a plain cross-fade, the clearing stays still.
        public let stepSlideMs: Double
        public let stepSlideShare: Double
        public let stepParallaxBackground: Double
    }

    public static func load(from url: URL) throws -> EngineConfig {
        try JSONDecoder().decode(EngineConfig.self, from: Data(contentsOf: url))
    }
}
