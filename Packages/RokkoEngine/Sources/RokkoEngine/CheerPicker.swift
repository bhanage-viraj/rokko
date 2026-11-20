//
//  CheerPicker.swift
//  The short cheer said before a right answer ("Yes!", "Well done!", …) or a finished game ("Hooray!", …),
//  so the words change every time. Deterministic: seed = the full round code, so the same round always
//  says the same cheers in the same order (CLAUDE.md: same seed → same child-facing content).
//  Never the same cheer twice in a row.
//

public struct CheerPicker: Sendable {
    private let seed: String
    private var turn = 0
    private var last: String?

    public init(seed: String) { self.seed = seed }

    /// Next cheer from `pool` (voice keys).
    public mutating func next(from pool: [String]) -> String {
        precondition(!pool.isEmpty)
        var i = Int(FNV1a.hash64("\(seed)#\(turn)") % UInt64(pool.count))
        if pool.count > 1, pool[i] == last { i = (i + 1) % pool.count }
        turn += 1
        last = pool[i]
        return pool[i]
    }
}
