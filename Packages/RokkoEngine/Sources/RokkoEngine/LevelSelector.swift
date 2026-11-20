//
//  LevelSelector.swift
//  P(known) → level 1–6 (docs/ENGINE.md §3). Bands from EngineConfig › levels.
//  0.05 buffer on band edges, at most one level step from the last level played,
//  level 5 needs the charcoal intro, level 6 needs Colour ≥ 0.50, Wobbly plays one level lower,
//  never above `maxLevel`.
//

import RokkoContent

public struct LevelSelector: Sendable {
    public let config: EngineConfig.Levels

    /// Cap from `config.maxLevel`, or `maxLevel` when given (tests of the level 4–6 rules).
    private let cap: Int

    public init(_ config: EngineConfig.Levels, maxLevel: Int? = nil) {
        self.config = config
        cap = maxLevel ?? config.maxLevel
    }

    private var bands: [EngineConfig.Levels.Band] { config.bands.sorted { $0.level < $1.level } }
    private var minLevel: Int { bands.first?.level ?? 1 }
    private var maxLevel: Int { min(bands.last?.level ?? 6, cap) }
    private func edge(_ level: Int) -> Double { bands.first { $0.level == level }?.min ?? 0 }

    /// The band P falls in, with no buffer or history.
    public func band(for p: Double) -> Int {
        bands.last { p >= $0.min }?.level ?? minLevel
    }

    public func isMastered(_ p: Double) -> Bool { p >= config.mastered }

    /// The level for the next round of an exercise.
    /// - lastLevel: last level played on this exercise (nil = never played).
    public func level(p: Double, lastLevel: Int?, colour: Double, charcoalIntroSeen: Bool, wobbly: Bool) -> Int {
        var level: Int
        if let last = lastLevel {
            level = last
            // Up: one band at a time, only when P is clearly past the next edge.
            var steps = 0
            while level < maxLevel, steps < config.maxStepPerRound, p >= edge(level + 1) + config.buffer {
                level += 1; steps += 1
            }
            // Down: only when P is clearly below this band's edge.
            steps = 0
            while level > minLevel, steps < config.maxStepPerRound, p < edge(level) - config.buffer {
                level -= 1; steps += 1
            }
        } else {
            level = band(for: p)
        }
        level = min(level, maxLevel)
        if config.level5RequiresCharcoalIntro, !charcoalIntroSeen { level = min(level, 4) }
        if level >= 6, colour < config.level6RequiresColour { level = 5 }
        if wobbly { level = max(minLevel, level - config.wobblyLevelDrop) }
        return level
    }
}
