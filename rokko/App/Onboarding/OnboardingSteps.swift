//
//  OnboardingSteps.swift
//  The page-style steps of first-run setup: welcome · chess · ready.
//  (look, tryGuardian and tryCheckIn run full screen: OnboardingPracticeSteps.swift.)
//  Also the pieces checklist the lesson reuses.
//

import SwiftUI

// MARK: - welcome

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 48) {
            Spacer(minLength: 0)
            CastlingCircles(startDelay: 0.4)
            OnboardingTitle(text: "Learn chess, side by side.")
            Spacer(minLength: 0)
        }
        .padding(.bottom, 124)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - chess

struct ChessStep: View {
    @Bindable var model: OnboardingViewModel

    var body: some View {
        VStack(spacing: 44) {
            Spacer(minLength: 0)
            OnboardingTitle(text: "Do you play chess?")
            HStack(spacing: 24) {
                ForEach(OnboardingViewModel.ChessExperience.allCases, id: \.self) { option in
                    OptionTile(imageName: option.imageName,
                               title: option.title,
                               selected: model.chess == option) { model.chess = option }
                }
            }
            Spacer(minLength: 0)
        }
        // Centre the group in the space between the progress bar and Continue.
        .padding(.bottom, 124)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Large selectable tile: picture and title. The whole tile is the target.
/// Selected = moss border, soft moss fill and a tick badge (same as the pieces checklist).
struct OptionTile: View {
    let imageName: String
    let title: String
    let selected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 24) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .offset(y: selected && !reduceMotion ? -4 : 0)
                    .accessibilityHidden(true)
                Text(title)
                    .font(RokkoFont.fredoka(32, scales: true))
                    .foregroundStyle(RokkoColor.ink)
            }
            .frame(width: 300, height: 250)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(selected ? RokkoColor.mossWash : RokkoColor.card))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(selected ? RokkoColor.moss : RokkoColor.cardEdge, lineWidth: 3))
            .overlay(alignment: .topTrailing) { TickCircle(on: selected, size: 34).padding(16) }
            .shadow(color: RokkoColor.ink.opacity(selected ? 0.12 : 0.06), radius: 10, y: 6)
            .animation(.easeOut(duration: 0.2), value: selected)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - ready

struct ReadyStep: View {
    let model: OnboardingViewModel

    var body: some View {
        let r = model.result
        let chips = model.summaryChips
        VStack(spacing: 40) {
            Spacer(minLength: 0)
            CastlingCircles()
            OnboardingTitle(text: "You're ready.")
            // A quiet summary, not buttons: icon + text, no border or fill.
            HStack(spacing: 18) {
                SummaryItem(systemImage: r.calm ? "leaf" : "paintpalette", text: chips[0])
                Circle().fill(RokkoColor.inkSoft.opacity(0.4)).frame(width: 5, height: 5)
                SummaryItem(systemImage: r.tipsMode == .full ? "list.number" : "text.alignleft", text: chips[1])
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 124)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SummaryItem: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(RokkoColor.teal)
                .accessibilityHidden(true)
            Text(text)
                .font(RokkoFont.nunito(20, .semibold, scales: true))
                .foregroundStyle(RokkoColor.inkSoft)
        }
    }
}

// MARK: - pieces checklist (used by the lesson)

/// Six piece tiles that tick on tap. The lesson shows it once before its first Guardian's turn.
struct PiecesChecklist: View {
    let selected: Set<OnboardingViewModel.Piece>
    let onToggle: (OnboardingViewModel.Piece) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 18) {
            ForEach(OnboardingViewModel.Piece.allCases) { piece in
                let on = selected.contains(piece)
                Button { onToggle(piece) } label: {
                    VStack(spacing: 10) {
                        Image(piece.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .offset(y: on && !reduceMotion ? -6 : 0)
                            .accessibilityHidden(true)
                        Text(piece.name)
                            .font(RokkoFont.fredoka(22, scales: true))
                            .foregroundStyle(RokkoColor.bark)
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 250, alignment: .bottom)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(on ? RokkoColor.mossWash : RokkoColor.card))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(on ? RokkoColor.moss : RokkoColor.cardEdge, lineWidth: 3))
                    .overlay(alignment: .topTrailing) { TickCircle(on: on, size: 36).padding(14) }
                    .animation(.easeOut(duration: 0.3), value: on)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(piece.name)
                .accessibilityValue(on ? "On the table" : "Not out yet")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}
