//
//  SeededRandom.swift
//  Seed = FNV-1a 64 of the full round code; PRNG = SplitMix64 (ENGINE §7, EngineConfig.generator).
//  Same code → same numbers on every device, every time.
//

public enum FNV1a {
    public static func hash64(_ string: String) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            h ^= UInt64(byte)
            h &*= 0x0000_0100_0000_01B3
        }
        return h
    }
}

public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }
    public init(code: String) { self.init(seed: FNV1a.hash64(code)) }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0 ..< upperBound. Explicit so the result never depends on the standard library's algorithm.
    public mutating func index(below upperBound: Int) -> Int {
        precondition(upperBound > 0)
        return Int(next() % UInt64(upperBound))
    }
}

extension Array {
    /// Fisher–Yates with our own index function, so it is stable across OS versions.
    func seededShuffle(_ rng: inout SplitMix64) -> [Element] {
        var a = self
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, rng.index(below: i + 1))
        }
        return a
    }
}
