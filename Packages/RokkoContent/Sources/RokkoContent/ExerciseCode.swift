//
//  ExerciseCode.swift
//  `LLL-M-TT-EE[-V-III]` = Lesson · Module · Type · Exercise · Level · pool row (docs/EXERCISES.md).
//

import Foundation

public struct ExerciseCode: Hashable, Sendable, CustomStringConvertible {
    public let lesson: Int
    public let module: Int
    public let type: Int
    public let exercise: Int
    public let level: Int?
    public let row: Int?

    public init?(_ string: String) {
        let parts = string.split(separator: "-").map { Int($0) }
        guard parts.count == 4 || parts.count == 6, !parts.contains(nil) else { return nil }
        let p = parts.map { $0! }
        lesson = p[0]; module = p[1]; type = p[2]; exercise = p[3]
        level = p.count == 6 ? p[4] : nil
        row = p.count == 6 ? p[5] : nil
    }

    /// `LLL-M-TT-EE`, without level and row.
    public var exerciseOnly: String {
        String(format: "%03d-%d-%02d-%02d", lesson, module, type, exercise)
    }

    public var description: String {
        guard let level, let row else { return exerciseOnly }
        return exerciseOnly + String(format: "-%d-%03d", level, row)
    }
}
