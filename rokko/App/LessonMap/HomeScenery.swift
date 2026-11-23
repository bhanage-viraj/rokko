//
//  HomeScenery.swift
//  Parallax scenery behind the lesson cards on the Guardian home.
//
//  Three depths, all driven by the lesson carousel's scroll offset (never by a timer):
//    far   – hills, mountains and clouds, move `RokkoMotion.homeParallaxFar` of the swipe
//    mid   – leaves, floating squares, pieces and peeking animals, `homeParallaxMid`
//    near  – the lesson card and its character, 1.0 (the scroll view itself)
//  Each lesson owns its own far and mid layer; neighbouring lessons cross-fade as the finger moves.
//  Calm and Reduce Motion: no parallax, the scenery only cross-fades.
//

import SwiftUI

/// Carousel position in lessons: 0 = first lesson centred, 1.5 = halfway between the 2nd and 3rd.
/// Only `HomeScenery` reads it, so a scroll frame re-renders the scenery and nothing else.
@MainActor @Observable
final class HomeScrollProgress {
    var page: CGFloat = 0
}

struct HomeScenery: View {
    let progress: HomeScrollProgress
    let lessonNumbers: [Int]
    /// Distance between two cards' centres, in design points: one full swipe.
    let pageWidth: CGFloat
    @Environment(\.canvasSize) private var canvas
    @MotionStill private var still

    var body: some View {
        let page = progress.page
        ZStack(alignment: .topLeading) {
            ForEach(Array(lessonNumbers.enumerated()), id: \.element) { index, number in
                // Distance of this lesson from the centre, in lessons (negative = already passed).
                let d = CGFloat(index) - page
                // Far scenery hands over smoothly across the whole swipe. Middle decorations hand
                // over in the middle third only, so two lessons' decorations never pile up.
                let far = Self.ease(1 - abs(d))
                let mid = Self.ease(min(1, max(0, 1.5 - 3 * abs(d))))
                if far > 0 {
                    SceneryFar(lesson: number, size: canvas)
                        .offset(x: still ? 0 : d * pageWidth * RokkoMotion.homeParallaxFar)
                        .opacity(far)
                }
                if mid > 0 {
                    SceneryMid(lesson: number, size: canvas)
                        .offset(x: still ? 0 : d * pageWidth * RokkoMotion.homeParallaxMid)
                        .opacity(mid)
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Smoothstep on 0...1: slow at both ends, so a hand-over has no visible start or stop.
    private static func ease(_ t: CGFloat) -> CGFloat {
        let t = min(1, max(0, t))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Far layer: hills, mountains, clouds

/// Static content: inputs never change while scrolling, so SwiftUI skips its body and the
/// layer is drawn once and only moved.
private struct SceneryFar: View, Equatable {
    let lesson: Int
    let size: CGSize

    /// Extra width on both sides so a shifted layer never shows its edge.
    private var bleed: CGFloat { size.width * 0.3 }

    var body: some View {
        let w = size.width, h = size.height
        ZStack(alignment: .topLeading) {
            clouds(w: w, h: h)
            ground(h: h)
                .frame(width: w + bleed * 2, height: h * 0.42)
                .offset(x: -bleed, y: h * 0.58)
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .drawingGroup()
    }

    @ViewBuilder private func ground(h: CGFloat) -> some View {
        switch lesson {
        case 1:   // jungle: two rows of round hills
            ZStack {
                RollingHills(crest: [0.45, 0.20, 0.40, 0.15, 0.35, 0.22, 0.42])
                    .fill(RokkoColor.sceneHillJungle.opacity(0.7))
                RollingHills(crest: [0.55, 0.40, 0.58, 0.36, 0.52, 0.42])
                    .fill(RokkoColor.sceneHillJungle)
            }
        case 2:   // meadow: long, flat, gentle slopes
            ZStack {
                RollingHills(crest: [0.40, 0.30, 0.36, 0.28, 0.38])
                    .fill(RokkoColor.sceneHillMeadow.opacity(0.7))
                RollingHills(crest: [0.58, 0.50, 0.56, 0.48, 0.54])
                    .fill(RokkoColor.sceneHillMeadow)
            }
        default:  // the lion's mountains: taller peaks behind a low ridge
            ZStack {
                RollingHills(crest: [0.50, 0.05, 0.45, 0.12, 0.48, 0.02, 0.40])
                    .fill(RokkoColor.sceneRidge.opacity(0.7))
                RollingHills(crest: [0.60, 0.42, 0.58, 0.46, 0.55, 0.44])
                    .fill(RokkoColor.sceneRidge)
            }
        }
    }

    @ViewBuilder private func clouds(w: CGFloat, h: CGFloat) -> some View {
        // Different sky per lesson, kept clear of the title (top-left) and buttons (top-right).
        let spots: [(x: CGFloat, y: CGFloat, s: CGFloat)] = switch lesson {
        case 1:  [(0.08, 0.30, 1.0), (0.93, 0.36, 0.8), (0.50, 0.11, 0.7)]
        case 2:  [(0.06, 0.40, 0.8), (0.95, 0.28, 1.0), (0.42, 0.08, 0.6)]
        default: [(0.10, 0.24, 0.9), (0.90, 0.44, 0.9), (0.58, 0.10, 0.6)]
        }
        ForEach(spots.indices, id: \.self) { i in
            Cloud()
                .frame(width: 180 * spots[i].s, height: 70 * spots[i].s)
                .position(x: w * spots[i].x, y: h * spots[i].y)
        }
    }
}

// MARK: - Mid layer: decorations in the gaps beside the card

private struct SceneryMid: View, Equatable {
    let lesson: Int
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        ZStack(alignment: .topLeading) {
            switch lesson {
            case 1: jungle(w: w, h: h)
            case 2: squares(w: w, h: h)
            default: pieces(w: w, h: h)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        .drawingGroup()
    }

    // Everything sits in the strip below the cards (and the bottom corners): the neighbouring
    // cards peek in at both sides, half see-through, so nothing is placed behind them.
    // Positions: x as a share of the width, y measured up from the bottom edge.

    private func jungle(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LeafTuft().frame(width: 120, height: 120).position(x: w * 0.03, y: h - 60)
            LeafTuft().frame(width: 64, height: 64).position(x: w * 0.30, y: h - 36)
            LeafTuft().frame(width: 56, height: 56).scaleEffect(x: -1).position(x: w * 0.70, y: h - 32)
            LeafTuft().frame(width: 110, height: 110).scaleEffect(x: -1).position(x: w * 0.97, y: h - 55)
            Image(Animal.elephant.imageName).resizable().scaledToFit()
                .frame(height: 104).position(x: w * 0.12, y: h - 60)
            Image(Animal.squirrel.imageName).resizable().scaledToFit()
                .frame(height: 78).position(x: w * 0.87, y: h - 46)
        }
    }

    private func squares(w: CGFloat, h: CGFloat) -> some View {
        let tiles: [(x: CGFloat, up: CGFloat, side: CGFloat, turn: Double, dark: Bool)] = [
            (0.04, 70, 52, -12, true), (0.11, 34, 40, 9, false), (0.20, 58, 34, 6, false),
            (0.31, 30, 28, -8, true), (0.69, 34, 30, 10, false), (0.79, 60, 36, -14, true),
            (0.89, 32, 42, -5, true), (0.96, 72, 50, 12, false),
        ]
        return ZStack(alignment: .topLeading) {
            ForEach(tiles.indices, id: \.self) { i in
                let t = tiles[i]
                RoundedRectangle(cornerRadius: t.side * 0.22, style: .continuous)
                    .fill(t.dark ? RokkoColor.sceneSquareDark : RokkoColor.sceneSquareLight)
                    .frame(width: t.side, height: t.side)
                    .rotationEffect(.degrees(t.turn))
                    .position(x: w * t.x, y: h - t.up)
            }
        }
    }

    private func pieces(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Capsule().fill(RokkoColor.sceneStone).frame(width: 110, height: 28).position(x: w * 0.08, y: h - 18)
            Capsule().fill(RokkoColor.sceneStone).frame(width: 64, height: 18).position(x: w * 0.28, y: h - 22)
            Capsule().fill(RokkoColor.sceneStone).frame(width: 100, height: 26).position(x: w * 0.92, y: h - 18)
            Image("piece_rook_ivory").resizable().scaledToFit()
                .frame(height: 110).position(x: w * 0.08, y: h - 70)
            Image("piece_pawn_ivory").resizable().scaledToFit()
                .frame(height: 76).position(x: w * 0.89, y: h - 52)
            Image("piece_pawn_ivory").resizable().scaledToFit()
                .frame(height: 60).position(x: w * 0.95, y: h - 44)
        }
    }
}

// MARK: - Shapes

/// A soft hill line across the top of its frame. `crest` is each bump's height from the top,
/// as a share of the frame height (0 = top); points are joined with smooth curves.
private struct RollingHills: Shape {
    let crest: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard crest.count > 1 else { return Path(rect) }
        let step = rect.width / CGFloat(crest.count - 1)
        let points = crest.enumerated().map { CGPoint(x: rect.minX + CGFloat($0) * step, y: rect.minY + $1 * rect.height) }
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: points[0])
        path.addLine(to: mid(points[0], points[1]))
        for i in 1..<(points.count - 1) {
            path.addQuadCurve(to: mid(points[i], points[i + 1]), control: points[i])
        }
        path.addLine(to: points[points.count - 1])
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Three puffs on a flat base.
private struct Cloud: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                Capsule().frame(width: w, height: h * 0.55).offset(y: h * 0.45)
                Circle().frame(width: h * 0.75).offset(x: w * 0.14, y: h * 0.18)
                Circle().frame(width: h).offset(x: w * 0.36, y: 0)
                Circle().frame(width: h * 0.65).offset(x: w * 0.62, y: h * 0.28)
            }
            .foregroundStyle(RokkoColor.sceneCloud)
        }
    }
}

/// A fan of rounded leaves growing from the bottom centre.
private struct LeafTuft: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack(alignment: .bottom) {
                ForEach([-50.0, -22, 4, 30, 56], id: \.self) { angle in
                    Capsule()
                        .fill(RokkoColor.sceneLeaf)
                        .frame(width: s * 0.22, height: s * 0.62)
                        .rotationEffect(.degrees(angle), anchor: .bottom)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
    }
}
