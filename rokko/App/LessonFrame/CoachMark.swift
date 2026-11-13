//
//  CoachMark.swift
//  Coach overlay for full-screen practice: a soft dim (or blur) with a cut-out and a gentle
//  honey ring around the target, plus a light speech bubble with a tail pointing at it.
//  Targets register their frame with `.coachTarget(_:)` (anchor preferences), so nothing is
//  positioned by hand.
//

import SwiftUI

/// Where the bubble sits next to its target.
enum CoachPlacement: Sendable {
    /// Above or below, whichever has more room (tail on the top or bottom edge).
    case vertical
    /// To the left, tail on its right edge pointing at the target (for tall targets at the right).
    case leading
}

enum CoachTarget: Hashable, Sendable {
    case next, again, guardian, guardianTurn, mood
}

private struct CoachTargetKey: PreferenceKey {
    static let defaultValue: [CoachTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [CoachTarget: Anchor<CGRect>], nextValue: () -> [CoachTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Registers this view's frame as a coach-mark target.
    func coachTarget(_ target: CoachTarget) -> some View {
        anchorPreference(key: CoachTargetKey.self, value: .bounds) { [target: $0] }
    }

    /// Draws the coach overlay over this view (in this view's coordinate space).
    /// - target: what the bubble points at. `nil` = no tail; the bubble sits at `fallback`.
    /// - highlight: ring the target and dim the rest.
    /// - isPresented: hide everything (e.g. while a clip plays or a sheet is open).
    /// - blursBackground: blur (not just dim) everything except the target.
    func coachOverlay<Bubble: View>(target: CoachTarget?,
                                    highlight: Bool = true,
                                    fallback: Alignment = .trailing,
                                    isPresented: Bool = true,
                                    blursBackground: Bool = false,
                                    bubbleWidth: CGFloat = 360,
                                    placement: CoachPlacement = .vertical,
                                    @ViewBuilder bubble: @escaping () -> Bubble) -> some View {
        overlayPreferenceValue(CoachTargetKey.self) { anchors in
            GeometryReader { proxy in
                if isPresented {
                    CoachOverlayLayout(target: target.flatMap { anchors[$0] }.map { proxy[$0] },
                                       highlight: highlight,
                                       container: proxy.size,
                                       fallback: fallback,
                                       blurs: blursBackground,
                                       bubbleWidth: bubbleWidth,
                                       placement: placement,
                                       bubble: bubble)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.1), value: isPresented)
            .animation(.spring(duration: 0.45, bounce: 0.1), value: target)
        }
    }
}

private struct CoachOverlayLayout<Bubble: View>: View {
    let target: CGRect?
    let highlight: Bool
    let container: CGSize
    let fallback: Alignment
    let blurs: Bool
    let bubbleWidth: CGFloat
    let placement: CoachPlacement
    let bubble: () -> Bubble

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let ringGap: CGFloat = 12
    private let bubbleGap: CGFloat = 22
    private let edge: CGFloat = 32
    /// `.leading`: how far down the bubble's right edge its tail sits.
    private let leadingTailInset: CGFloat = 56

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let target {
                let ring = target.insetBy(dx: -ringGap, dy: -ringGap)
                // Buttons get a pill / circle; larger areas (a panel) get a soft rounded rectangle.
                let radius = min(ring.height, ring.width) <= 140 ? min(ring.height, ring.width) / 2 : 32
                let below = ring.midY < container.height / 2
                let left = bubbleLeft(ring: ring)

                if highlight {
                    let surround = Path { p in
                        p.addRect(CGRect(origin: .zero, size: container))
                        p.addRoundedRect(in: ring, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
                    }
                    Group {
                        if blurs { surround.fill(.thinMaterial, style: FillStyle(eoFill: true)) }
                        surround.fill(RokkoColor.ink.opacity(blurs ? 0.14 : 0.2), style: FillStyle(eoFill: true))
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(RokkoColor.honey, lineWidth: 4)
                        .background(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .stroke(RokkoColor.honey.opacity(pulse ? 0 : 0.45), lineWidth: pulse ? 26 : 4)
                                .padding(pulse ? -6 : 0)
                        )
                        .frame(width: ring.width, height: ring.height)
                        .offset(x: ring.minX, y: ring.minY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                switch placement {
                case .vertical:
                    SpeechBubble(width: bubbleWidth,
                                 tail: below ? .top : .bottom,
                                 tailPosition: min(max(ring.midX - left, 32), bubbleWidth - 32),
                                 content: bubble)
                        .alignmentGuide(.top) { d in
                            -(below ? ring.maxY + bubbleGap : ring.minY - bubbleGap - d.height)
                        }
                        .offset(x: left)
                case .leading:
                    // Tail points at the target's middle; the bubble hangs down from there.
                    let top = max(ring.midY - leadingTailInset, edge)
                    SpeechBubble(width: bubbleWidth,
                                 tail: .trailing,
                                 tailPosition: ring.midY - top,
                                 content: bubble)
                        .offset(x: max(ring.minX - bubbleGap - bubbleWidth, edge), y: top)
                }
            } else {
                SpeechBubble(width: bubbleWidth, tail: nil, tailPosition: 0, content: bubble)
                    .padding(edge)
                    .frame(width: container.width, height: container.height, alignment: fallback)
            }
        }
        .frame(width: container.width, height: container.height, alignment: .topLeading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// Right edge lines up with the target's right edge, kept inside the container.
    private func bubbleLeft(ring: CGRect) -> CGFloat {
        min(max(ring.maxX - bubbleWidth, edge), container.width - bubbleWidth - edge)
    }
}

/// Cream bubble with a soft shadow and an optional tail on its top, bottom or right edge.
private struct SpeechBubble<Content: View>: View {
    enum Tail { case top, bottom, trailing }

    let width: CGFloat
    let tail: Tail?
    /// x along the top / bottom edge, or y down the right edge.
    let tailPosition: CGFloat
    let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(RokkoColor.card))
            .overlay(alignment: overlayAlignment) {
                if let tail {
                    BubbleTail()
                        .fill(RokkoColor.card)
                        .frame(width: 26, height: 13)
                        .rotationEffect(.degrees(rotation(tail)))
                        .offset(offset(tail))
                }
            }
            .shadow(color: RokkoColor.ink.opacity(0.16), radius: 18, y: 8)
    }

    private var overlayAlignment: Alignment {
        switch tail {
        case .bottom: .bottomLeading
        case .trailing: .topTrailing
        default: .topLeading
        }
    }

    /// The tail shape points down; turn it to face its edge.
    private func rotation(_ tail: Tail) -> Double {
        switch tail {
        case .top: 180
        case .bottom: 0
        case .trailing: -90
        }
    }

    private func offset(_ tail: Tail) -> CGSize {
        switch tail {
        case .top: CGSize(width: tailPosition - 13, height: -12)
        case .bottom: CGSize(width: tailPosition - 13, height: 12)
        // Turned 90°, the 26 × 13 tail's centre must move from (−13, 6.5) to just past the edge.
        case .trailing: CGSize(width: 18, height: tailPosition - 6.5)
        }
    }
}

/// Downward-pointing rounded tail.
private struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.midX + 3, y: r.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.midX - 3, y: r.maxY - 2))
        return p
    }
}

enum CoachText {
    /// `**word**` → leaf green, extra bold (readable on the cream bubble). Line breaks are kept.
    static func styled(_ text: String, size: CGFloat) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var result = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        for run in result.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            result[run.range].foregroundColor = RokkoColor.leaf
            result[run.range].font = RokkoFont.nunito(size, .black, scales: true)
        }
        return result
    }
}
