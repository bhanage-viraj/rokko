//
//  VoiceLines.swift
//  voice_lines.csv: one row per recorded line. Captions must match the recording word for word,
//  so the app only ever shows `text` from this file.
//

import Foundation

public struct VoiceLine: Sendable, Hashable {
    public let id: String
    public let file: String
    public let speaker: String
    public let text: String
}

public struct VoiceLines: Sendable {
    public let lines: [String: VoiceLine]

    public init(lines: [VoiceLine]) {
        self.lines = Dictionary(lines.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public subscript(id: String) -> VoiceLine? { lines[id] }

    public static func load(from url: URL) throws -> VoiceLines {
        try parse(String(contentsOf: url, encoding: .utf8))
    }

    /// RFC 4180-style CSV: quoted fields may hold commas, quotes ("") and newlines.
    public static func parse(_ csv: String) throws -> VoiceLines {
        let rows = parseRows(csv)
        guard let header = rows.first else { return VoiceLines(lines: []) }
        func col(_ name: String) throws -> Int {
            guard let i = header.firstIndex(of: name) else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "voice_lines.csv has no \(name) column"])
            }
            return i
        }
        let id = try col("id"), file = try col("file"), speaker = try col("speaker"), text = try col("text")
        let needed = max(id, file, speaker, text)
        let lines = rows.dropFirst().compactMap { r -> VoiceLine? in
            guard r.count > needed, !r[id].isEmpty else { return nil }
            return VoiceLine(id: r[id], file: r[file], speaker: r[speaker], text: r[text])
        }
        return VoiceLines(lines: lines)
    }

    static func parseRows(_ s: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(s.unicodeScalars)[...]
        while let ch = chars.popFirst() {
            if quoted {
                if ch == "\"" {
                    if chars.first == "\"" { field.unicodeScalars.append("\""); chars.removeFirst() }
                    else { quoted = false }
                } else {
                    field.unicodeScalars.append(ch)
                }
            } else {
                switch ch {
                case "\"": quoted = true
                case ",": row.append(field); field = ""
                case "\r": break
                case "\n": row.append(field); rows.append(row); row = []; field = ""
                default: field.unicodeScalars.append(ch)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}
