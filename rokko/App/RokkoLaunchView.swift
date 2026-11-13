//
//  RokkoLaunchView.swift
//  Rokko — loading screen (iPadOS 17+, SwiftUI only)
//
//  Story in ~3.3 s:
//    1. A row of four squares fades in with the ivory King (left) and Rook (right).
//    2. CASTLING (O-O): the King glides two squares right; the Rook sweeps
//       behind him in a soft arc and lands on his left, drawing a honey-gold trail.
//    3. The Rook melts into the big green circle, the King into the small honey
//       circle, and the trail bends into the logo arc.
//    4. "rokko" slides in. Short hold, then fade into the app.
//
//  Tap anywhere = skip to the logo.  Reduce Motion / Calm mode = logo fade only.
//
//  ASSETS (Assets.xcassets, transparent PNG, side view like the app's piece art):
//    "KingIvory"   – the ivory king
//    "RookIvory"   – the ivory rook
//  FONT: add Fredoka-SemiBold.ttf to the target and list it under
//        "Fonts provided by application" (UIAppFonts) in Info.plist.
//  LAUNCH SCREEN: Info.plist > UILaunchScreen > Background color = cream (#F4F0E3),
//        nothing else, so the first frame of this view matches it exactly.
//

import SwiftUI

// MARK: - Brand

enum RokkoBrand {
    static let cream     = Color(hex: 0xF4F0E3)
    static let green     = Color(hex: 0x2F4A3E)   // set to your logo's exact green if it differs
    static let honey     = Color(hex: 0xE2B24A)
    static let tileLight = Color(hex: 0xECE4CC)
    static let tileMoss  = Color(hex: 0xA9B98C)
    static let shadow    = Color(hex: 0x2F4A3E).opacity(0.14)

    static func wordmark(_ size: CGFloat) -> Font {
        UIFont(name: "Fredoka-SemiBold", size: size) != nil
            ? .custom("Fredoka-SemiBold", size: size)
            : .system(size: size, weight: .semibold, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Timings (all in seconds — tune here)

struct RokkoLaunchTimings {
    var intro: Double       = 0.35   // squares + pieces fade up
    var kingMove: Double    = 0.70   // king glides 2 squares
    var rookDelay: Double   = 0.35   // rook starts while the king is still moving
    var rookMove: Double    = 0.85   // rook sweeps behind the king
    var settle: Double      = 0.15   // tiny pause after castling
    var dissolve: Double    = 0.45   // pieces melt into circles
    var toLogo: Double      = 0.55   // circles + arc glide into the logo
    var wordmarkDelay: Double = 0.15
    var wordmark: Double    = 0.45
    var hold: Double        = 0.55
    var exit: Double        = 0.35
    var calmFade: Double    = 0.6
}

// MARK: - Layout (points, relative to the screen centre)

private enum Geo {
    static let square: CGFloat = 170
    static let tileHeight: CGFloat = 26
    static let groundY: CGFloat = 120            // top edge of the squares
    static func x(_ i: Int) -> CGFloat { (CGFloat(i) - 1.5) * square }

    static let kingHeight: CGFloat = 300
    static let rookHeight: CGFloat = 235
    static let kingWidth: CGFloat = 130
    static let rookWidth: CGFloat = 130

    static func kingCentreY() -> CGFloat { groundY - kingHeight / 2 + 4 }
    static func rookCentreY() -> CGFloat { groundY - rookHeight / 2 + 4 }

    // Castling squares: King 0 → 2, Rook 3 → 1
    static let kingFrom = x(0), kingTo = x(2)
    static let rookFrom = x(3), rookTo = x(1)

    // Final logo
    static let bigR: CGFloat = 48
    static let smallR: CGFloat = 29
    static let baseline: CGFloat = 40
    static var big: CGPoint   { CGPoint(x: -222, y: baseline - bigR) }
    static var small: CGPoint { CGPoint(x: -146, y: baseline - smallR) }
    static let wordSize: CGFloat = 118
    static var word: CGPoint  { CGPoint(x: 92, y: baseline - 46) }

    // Honey trail (above the pieces) → becomes the logo arc
    static var trail: ArcPoints {
        ArcPoints(p0: CGPoint(x: rookFrom, y: groundY - rookHeight - 34),
                  p1: CGPoint(x: x(2) - 20, y: groundY - kingHeight - 150),
                  p2: CGPoint(x: rookTo,   y: groundY - rookHeight - 34))
    }
    static var logoArc: ArcPoints {
        ArcPoints(p0: CGPoint(x: big.x - bigR * 0.35, y: big.y - bigR - 14),
                  p1: CGPoint(x: (big.x + small.x) / 2 + 30, y: big.y - bigR - 95),
                  p2: CGPoint(x: small.x + smallR * 0.95, y: small.y - 8))
    }
}

// MARK: - Animatable helpers

struct ArcPoints: Equatable {
    var p0: CGPoint, p1: CGPoint, p2: CGPoint
}

/// A quadratic curve whose three points animate, so the trail can bend smoothly into the logo arc.
private struct MorphArc: Shape {
    var arc: ArcPoints

    var animatableData: AnimatablePair<AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData>, CGPoint.AnimatableData> {
        get { AnimatablePair(AnimatablePair(arc.p0.animatableData, arc.p1.animatableData), arc.p2.animatableData) }
        set {
            arc.p0.animatableData = newValue.first.first
            arc.p1.animatableData = newValue.first.second
            arc.p2.animatableData = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        func p(_ q: CGPoint) -> CGPoint { CGPoint(x: c.x + q.x, y: c.y + q.y) }
        var path = Path()
        path.move(to: p(arc.p0))
        path.addQuadCurve(to: p(arc.p2), control: p(arc.p1))
        return path
    }
}

/// Moves a piece from one square to another with a lift (sine arc), a depth scale and a lean,
/// all driven by one progress value so the motion is perfectly continuous.
private struct Travel: ViewModifier, Animatable {
    var t: CGFloat                 // 0 → 1
    var fromX: CGFloat, toX: CGFloat, y: CGFloat
    var lift: CGFloat              // points upward at the peak
    var depthScale: CGFloat        // e.g. 0.9 = 10% smaller at the peak (passing behind)
    var lean: Double               // degrees at the peak

    var animatableData: CGFloat { get { t } set { t = newValue } }

    func body(content: Content) -> some View {
        let s = sin(.pi * t)                       // 0 → 1 → 0
        let x = fromX + (toX - fromX) * t
        return content
            .rotationEffect(.degrees(lean * s), anchor: .bottom)
            .scaleEffect(1 - (1 - depthScale) * s, anchor: .bottom)
            .offset(x: x, y: y - lift * s)
    }
}

/// Soft ground shadow that follows a piece and fades while it is lifted.
private struct ShadowTravel: ViewModifier, Animatable {
    var t: CGFloat
    var fromX: CGFloat, toX: CGFloat, liftFade: CGFloat
    var animatableData: CGFloat { get { t } set { t = newValue } }
    func body(content: Content) -> some View {
        let s = sin(.pi * t)
        return content
            .scaleEffect(1 - 0.35 * s * liftFade)
            .opacity(1 - 0.7 * s * liftFade)
            .offset(x: fromX + (toX - fromX) * t, y: Geo.groundY + 2)
    }
}

// MARK: - The view

struct RokkoLaunchView: View {
    var calmMode = false
    var timings = RokkoLaunchTimings()
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var introIn = false
    @State private var kingT: CGFloat = 0
    @State private var rookT: CGFloat = 0
    @State private var trailTrim: CGFloat = 0
    @State private var trail = Geo.trail
    @State private var piecesGone = false
    @State private var circlesBorn = false     // circles appear where the pieces stand
    @State private var circlesHome = false     // circles glide into the logo layout
    @State private var wordIn = false
    @State private var screenOpacity = 1.0
    @State private var done = false
    @State private var skipping = false

    // one easing everywhere: slow in, slow out
    private func ease(_ d: Double) -> Animation { .timingCurve(0.45, 0.0, 0.25, 1.0, duration: d) }
    private func soft(_ d: Double) -> Animation { .spring(duration: d, bounce: 0) }

    var body: some View {
        ZStack {
            RokkoBrand.cream.ignoresSafeArea()

            board
            pieces
            trailView
            logo
        }
        .opacity(screenOpacity)
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rokko")
        .accessibilityAddTraits(.isImage)
        .task { await play() }
    }

    // MARK: Layers

    private var board: some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(i.isMultiple(of: 2) ? RokkoBrand.tileLight : RokkoBrand.tileMoss)
                    .frame(width: Geo.square - 8, height: Geo.tileHeight)
                    .frame(width: Geo.square)
            }
        }
        .offset(y: Geo.groundY + Geo.tileHeight / 2 + (introIn ? 0 : 10))
        .opacity(piecesGone ? 0 : (introIn ? 1 : 0))
    }

    private var pieces: some View {
        ZStack {
            // shadows
            Ellipse().fill(RokkoBrand.shadow)
                .frame(width: 120, height: 18)
                .modifier(ShadowTravel(t: rookT, fromX: Geo.rookFrom, toX: Geo.rookTo, liftFade: 1))
            Ellipse().fill(RokkoBrand.shadow)
                .frame(width: 120, height: 18)
                .modifier(ShadowTravel(t: kingT, fromX: Geo.kingFrom, toX: Geo.kingTo, liftFade: 0.3))

            // rook passes BEHIND the king, so it is drawn first
            Image("RookIvory")
                .resizable().scaledToFit()
                .frame(width: Geo.rookWidth, height: Geo.rookHeight)
                .modifier(Travel(t: rookT, fromX: Geo.rookFrom, toX: Geo.rookTo,
                                 y: Geo.rookCentreY(), lift: 70, depthScale: 0.9, lean: -6))
                .zIndex(0)

            Image("KingIvory")
                .resizable().scaledToFit()
                .frame(width: Geo.kingWidth, height: Geo.kingHeight)
                .modifier(Travel(t: kingT, fromX: Geo.kingFrom, toX: Geo.kingTo,
                                 y: Geo.kingCentreY(), lift: 12, depthScale: 1, lean: 3))
                .zIndex(1)
        }
        .opacity(piecesGone ? 0 : (introIn ? 1 : 0))
        .scaleEffect(piecesGone ? 0.55 : 1, anchor: .center)
        .blur(radius: piecesGone ? 6 : 0)
        .offset(y: introIn ? 0 : 12)
        .accessibilityHidden(true)
    }

    private var trailView: some View {
        MorphArc(arc: trail)
            .trim(from: 0, to: trailTrim)
            .stroke(RokkoBrand.honey, style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }

    private var logo: some View {
        ZStack {
            // big green circle: born on the rook, glides home
            Circle().fill(RokkoBrand.green)
                .frame(width: Geo.bigR * 2, height: Geo.bigR * 2)
                .scaleEffect(circlesHome ? 1 : (circlesBorn ? 0.85 : 0.2))
                .offset(x: circlesHome ? Geo.big.x : Geo.rookTo,
                        y: circlesHome ? Geo.big.y : Geo.rookCentreY())
                .opacity(circlesBorn ? 1 : 0)

            // small honey circle: born on the king, glides home
            Circle().fill(RokkoBrand.honey)
                .frame(width: Geo.smallR * 2, height: Geo.smallR * 2)
                .scaleEffect(circlesHome ? 1 : (circlesBorn ? 0.85 : 0.2))
                .offset(x: circlesHome ? Geo.small.x : Geo.kingTo,
                        y: circlesHome ? Geo.small.y : Geo.kingCentreY())
                .opacity(circlesBorn ? 1 : 0)

            Text("rokko")
                .font(RokkoBrand.wordmark(Geo.wordSize))
                .foregroundStyle(RokkoBrand.green)
                .offset(x: Geo.word.x + (wordIn ? 0 : 28), y: Geo.word.y)
                .opacity(wordIn ? 1 : 0)
                .blur(radius: wordIn ? 0 : 4)
        }
    }

    // MARK: Sequence

    private func play() async {
        if reduceMotion || calmMode {
            jumpToLogo(duration: timings.calmFade)
            await wait(timings.calmFade + timings.hold)
            await finish(); return
        }

        // 1. intro
        withAnimation(soft(timings.intro)) { introIn = true }
        await wait(timings.intro)
        if skipping { return }

        // 2. castling — king first, rook overlaps so it feels like one move
        withAnimation(ease(timings.kingMove)) { kingT = 1 }
        await wait(timings.rookDelay)
        if skipping { return }
        withAnimation(ease(timings.rookMove)) {
            rookT = 1
            trailTrim = 1
        }
        await wait(timings.rookMove + timings.settle)
        if skipping { return }

        // 3. pieces melt into circles where they stand
        withAnimation(ease(timings.dissolve)) {
            piecesGone = true
            circlesBorn = true
        }
        await wait(timings.dissolve * 0.7)
        if skipping { return }

        // 4. circles + arc glide into the logo; wordmark follows
        withAnimation(soft(timings.toLogo)) {
            circlesHome = true
            trail = Geo.logoArc
        }
        await wait(timings.wordmarkDelay)
        withAnimation(soft(timings.wordmark)) { wordIn = true }
        await wait(max(timings.toLogo, timings.wordmark) + timings.hold)
        if skipping { return }

        await finish()
    }

    private func skip() {
        guard !skipping, !done else { return }
        skipping = true
        jumpToLogo(duration: 0.3)
        Task {
            await wait(0.3 + timings.hold)
            await finish()
        }
    }

    private func jumpToLogo(duration: Double) {
        withAnimation(soft(duration)) {
            introIn = true
            kingT = 1; rookT = 1
            trailTrim = 1
            trail = Geo.logoArc
            piecesGone = true
            circlesBorn = true
            circlesHome = true
            wordIn = true
        }
    }

    @MainActor private func finish() async {
        guard !done else { return }
        done = true
        withAnimation(ease(timings.exit)) { screenOpacity = 0 }
        await wait(timings.exit)
        onFinished()
    }

    private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
}

#Preview("Rokko launch") { RokkoLaunchView() }
#Preview("Rokko launch · Calm") { RokkoLaunchView(calmMode: true) }
