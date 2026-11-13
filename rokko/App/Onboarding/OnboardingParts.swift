//
//  OnboardingParts.swift
//  Building blocks for first-run setup: top bar with progress, title, CTA, tick,
//  coach bubble text and choices, castling circles.
//

import SwiftUI

// MARK: - Top chrome

struct OnboardingTopBar: View {
    let model: OnboardingViewModel
    /// A practice step is done and about to move on: a moss tick shows by the step count.
    var advancing = false

    var body: some View {
        HStack(spacing: 22) {
            GuardianIconButton(systemName: "chevron.left", label: "Back") { model.back() }
                .opacity(model.showsBack ? 1 : 0)
                .disabled(!model.showsBack)
                .accessibilityHidden(!model.showsBack)

            HStack(spacing: 8) {
                ForEach(Array(OnboardingViewModel.countedSteps.enumerated()), id: \.offset) { index, _ in
                    ProgressSegment(fill: fill(for: index))
                }
                HStack(spacing: 8) {
                    TickCircle(on: true, size: 24)
                        .opacity(advancing ? 1 : 0)
                        .scaleEffect(advancing ? 1 : 0.6)
                    Text(model.progressLabel)
                        .font(RokkoFont.nunito(15, .heavy, scales: true))
                        .foregroundStyle(RokkoColor.teal)
                }
                .frame(minWidth: 140, alignment: .trailing)
                .animation(.spring(duration: 0.4, bounce: 0.2), value: advancing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(advancing ? "Done. \(model.progressLabel)" : model.progressLabel)

            GuardianIconButton(systemName: "forward.end.fill", label: "Skip setup") { model.skip() }
                .modifier(SkipAvailability(available: model.canSkip))
                .opacity(model.showsSkip ? 1 : 0)
                .disabled(!model.showsSkip)
                .accessibilityHidden(!model.showsSkip)
        }
        .frame(height: 56)
    }

    /// Segments up to and including the current step are full; the rest are empty.
    private func fill(for index: Int) -> CGFloat {
        guard let n = model.progressNumber else { return model.step == .welcome ? 0 : 1 }
        return index < n ? 1 : 0
    }
}

private struct ProgressSegment: View {
    let fill: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(RokkoColor.mistTrack)
                Capsule().fill(RokkoColor.teal).frame(width: geo.size.width * fill)
            }
        }
        .frame(height: 10)
        .animation(.easeInOut(duration: 0.35), value: fill)
    }
}

/// I'll do it later: teal text, 56 pt tall touch target.
struct OnboardingTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RokkoFont.nunito(18, .heavy, scales: true))
            .foregroundStyle(RokkoColor.teal)
            .padding(.horizontal, 8)
            .frame(minWidth: 64, minHeight: 56)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Title

/// The one line of copy on page-style steps.
struct OnboardingTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(RokkoFont.fredoka(48, scales: true))
            .foregroundStyle(RokkoColor.ink)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons

/// Big leaf pill, bottom-right. Faded and inert until the step's action is done.
struct OnboardingCTA: View {
    let title: String
    var arrow = false
    var height: CGFloat = 84
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                if arrow {
                    Image(systemName: "arrow.right").font(.system(size: 24, weight: .heavy)).accessibilityHidden(true)
                }
            }
            .font(RokkoFont.fredoka(28, scales: true))
            .foregroundStyle(RokkoColor.card)
            .padding(.horizontal, 34)
            .frame(minWidth: 180, minHeight: height)
            .background(
                Capsule().fill(RokkoColor.leaf)
                    .shadow(color: RokkoColor.leaf.opacity(enabled ? 0.22 : 0), radius: 7, y: 6)
            )
            .opacity(enabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.3), value: enabled)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!enabled)
    }
}

struct TickCircle: View {
    let on: Bool
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(on ? RokkoColor.moss : .clear)
            Circle().strokeBorder(on ? RokkoColor.moss : RokkoColor.cardEdge, lineWidth: 3)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .black))
                .foregroundStyle(RokkoColor.card)
                .opacity(on ? 1 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - App steps: bubble text and choices

/// The one line inside a coach bubble. `**word**` is emphasised.
struct CoachMessage: View {
    let text: String
    var body: some View {
        Text(CoachText.styled(text, size: 22))
            .font(RokkoFont.nunito(22, .bold, scales: true))
            .lineSpacing(3)
            .foregroundStyle(RokkoColor.ink)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Answer inside a coach bubble. Selected = moss border, soft moss fill and tick.
struct CoachChoice: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(RokkoFont.nunito(20, .heavy, scales: true)).foregroundStyle(RokkoColor.ink)
                Spacer()
                TickCircle(on: selected, size: 28)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? RokkoColor.mossWash : RokkoColor.paper))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? RokkoColor.moss : RokkoColor.cardEdge, lineWidth: 2))
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.2), value: selected)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Skip stays blurred and inert until chess and look are answered.
struct SkipAvailability: ViewModifier {
    let available: Bool
    func body(content: Content) -> some View {
        content
            .disabled(!available)
            .blur(radius: available ? 0 : 3)
            .opacity(available ? 1 : 0.45)
            .animation(.easeOut(duration: 0.3), value: available)
            .accessibilityHint(available ? "" : "Available after the first two questions")
    }
}

// MARK: - Castling circles

/// Rook (leaf, big) and King (honey, small) castle: king 0.7 s, rook 0.15 s later over 0.85 s.
/// Reduce Motion: shows the end state.
struct CastlingCircles: View {
    var startDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var kingMoved = false
    @State private var rookMoved = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle().fill(RokkoColor.leaf)
                .frame(width: 96, height: 96)
                .offset(x: rookMoved ? 52 : 0, y: 40)
            Circle().fill(RokkoColor.honey)
                .frame(width: 58, height: 58)
                .offset(x: kingMoved ? 122 : 200, y: 58)
        }
        .frame(width: 260, height: 150, alignment: .topLeading)
        .accessibilityHidden(true)
        .task {
            if reduceMotion { kingMoved = true; rookMoved = true; return }
            try? await Task.sleep(for: .seconds(startDelay))
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: RokkoMotion.castleKing)) { kingMoved = true }
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: RokkoMotion.castleRook)
                .delay(RokkoMotion.castleRookDelay)) { rookMoved = true }
        }
    }
}
