//
//  OnboardingSteps.swift
//  The page-style steps of first-run setup: welcome · ready.
//  (look, tryGuardian and tryCheckIn run full screen: OnboardingPracticeSteps.swift.)
//  Also the pieces checklist the lesson reuses.
//

import SwiftUI
import RokkoContent

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

