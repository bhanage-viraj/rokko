//
//  OnboardingView.swift
//  First-run setup, shown once after the launch animation (docs/ONBOARDING.md).
//  welcome → chess → look → tryGuardian → tryCheckIn → ready. Next is the main button from the start.
//  welcome, chess and ready are pages (top bar + Continue). look and the three practice steps
//  show the real app full screen; their coach card carries Back / Skip / Continue.
//

import SwiftUI

struct OnboardingView: View {
    @State var model: OnboardingViewModel
    @State private var advancing = false
    /// Called after "Start Lesson 1", once the answers are saved.
    let onFinished: (OnboardingViewModel) -> Void

    var body: some View {
        DesignCanvas(background: RokkoColor.mistBlue) {
            ZStack(alignment: .topLeading) {
                if model.showsTopBar {
                    OnboardingTopBar(model: model, advancing: advancing)
                        .frame(width: 1194 - 80)
                        .offset(x: 40, y: 26)
                }
                if model.isFullScreen {
                    // The real lesson screen, just below the setup bar, scaled to the height left.
                    stepContent
                        .id(model.step)
                        .frame(width: 1194, height: 834)
                        .clipShape(RoundedRectangle(cornerRadius: 28 / Self.appScale, style: .continuous))
                        .scaleEffect(Self.appScale, anchor: .top)
                        .frame(width: 1194, height: 834 - Self.appTop, alignment: .top)
                        .shadow(color: RokkoColor.ink.opacity(0.14), radius: 16, y: 8)
                        .offset(y: Self.appTop)
                        .transition(.opacity)
                } else {
                    stepContent
                        .id(model.step)
                        .frame(width: 1194, height: 834 - 96, alignment: .topLeading)
                        .offset(y: 96)
                        .transition(.opacity)
                    ctaRow
                }
            }
            .animation(.easeInOut(duration: RokkoMotion.screenFade), value: model.step)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        // Practice steps move on by themselves once done: tick, short pause, next step.
        .task(id: AdvanceKey(step: model.step, done: model.canContinue)) {
            advancing = false
            guard model.autoAdvances, model.canContinue else { return }
            advancing = true
            let from = model.step
            try? await Task.sleep(for: .seconds(model.autoAdvanceDelay))
            guard !Task.isCancelled, model.step == from, model.canContinue else { return }
            model.next()
        }
        .environment(\.lessonFrameMode, model.frameMode)
    }

    /// Space for the setup bar above the lesson screen, and the scale that fits it below.
    private static let appTop: CGFloat = 96
    private static var appScale: CGFloat { (834 - appTop - 16) / 834 }
    /// Where the lesson frame's Next (right 40, bottom 34, 200 × 100) lands once scaled and placed.
    private static var nextTrailing: CGFloat { (1194 - 1194 * appScale) / 2 + 40 * appScale }
    private static var nextBottom: CGFloat { 834 - appTop - 834 * appScale + 34 * appScale }
    static var nextHeight: CGFloat { 100 * appScale }

    @ViewBuilder private var stepContent: some View {
        let calm = model.look != .standard
        switch model.step {
        case .welcome: WelcomeStep()
        case .chess: ChessStep(model: model)
        case .look: LookStep(model: model)
        case .tryGuardian: TryGuardianStep(model: model)
        case .tryCheckIn: TryCheckInStep(model: model, calm: calm)
        case .ready: ReadyStep(model: model)
        }
    }

    private var ctaRow: some View {
        OnboardingCTA(title: model.continueTitle,
                      arrow: true,
                      height: Self.nextHeight,
                      enabled: model.canContinue) {
            if model.step == .ready {
                onFinished(model)
            } else {
                model.next()
            }
        }
        // Same spot as the lesson's Next on the app steps (scaled frame below the bar),
        // so the main button never moves between steps.
        .padding(.trailing, Self.nextTrailing)
        .padding(.bottom, Self.nextBottom)
        .frame(width: 1194, height: 834, alignment: .bottomTrailing)
    }
}

private struct AdvanceKey: Equatable {
    let step: OnboardingViewModel.Step
    let done: Bool
}

#Preview(traits: .landscapeLeft) {
    OnboardingView(model: OnboardingViewModel(startAt: .tryGuardian)) { _ in }
}
