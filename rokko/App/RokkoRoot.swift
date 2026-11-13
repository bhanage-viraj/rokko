//
//  RokkoRoot.swift
//  Launch animation (every cold launch) → first-run setup (once) → lesson map → lesson.
//

import SwiftUI
import SwiftData

struct RokkoRoot: View {
    @Environment(\.modelContext) private var context
    @State private var settings: AppSettings?
    @State private var screen: Screen = .launch

    private enum Screen { case launch, onboarding, lessonMap, lesson }

    var body: some View {
        ZStack {
            switch screen {
            case .launch:
                // Castling always runs; only iOS Reduce Motion swaps it for the logo fade.
                RokkoLaunchView { show(screenAfterLaunch) }
                .transition(.opacity)
            case .onboarding:
                OnboardingView(model: OnboardingViewModel(startAt: Self.debugStartStep)) { model in
                    if let settings { model.save(to: settings) }
                    try? context.save()
                    show(.lessonMap)
                }
                .transition(.opacity)
            case .lessonMap:
                if let settings {
                    LessonMapView(settings: settings,
                                  onStartLesson: { show(.lesson) },
                                  onRunSetupAgain: { show(.onboarding) })
                        .transition(.opacity)
                }
            case .lesson:
                LessonPlaceholderView { show(.lessonMap) }
                    .transition(.opacity)
            }
        }
        .onAppear {
            settings = Store.settings(in: context)
        }
    }

    private var screenAfterLaunch: Screen {
        #if DEBUG
        // `-RokkoScreen lessonMap` / `-RokkoOnboardingStep <step>` jump straight there.
        if UserDefaults.standard.string(forKey: "RokkoScreen") == "lessonMap" { return .lessonMap }
        if Self.debugStartStep != .welcome { return .onboarding }
        #endif
        return settings?.onboardingDone == true ? .lessonMap : .onboarding
    }

    private func show(_ next: Screen) {
        withAnimation(.easeInOut(duration: RokkoMotion.screenFade)) { screen = next }
    }

    /// DEBUG only: launch with `-RokkoOnboardingStep tryGuardian` (any step name) to open that step.
    private static var debugStartStep: OnboardingViewModel.Step {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "RokkoOnboardingStep"),
           let step = OnboardingViewModel.Step.allCases.first(where: { "\($0)" == raw }) {
            return step
        }
        #endif
        return .welcome
    }
}

/// Stand-in until the lesson (opening film onward) is built.
private struct LessonPlaceholderView: View {
    let onBack: () -> Void

    var body: some View {
        DesignCanvas(background: RokkoColor.paper) {
            VStack(spacing: 24) {
                Text("Lesson 1 opens here")
                    .font(RokkoFont.fredoka(44))
                    .foregroundStyle(RokkoColor.ink)
                Text("Not built yet.")
                    .font(RokkoFont.nunito(21))
                    .foregroundStyle(RokkoColor.inkSoft)
                SecondaryButton(title: "Back to lessons", action: onBack)
                    .frame(width: 320)
            }
            .frame(width: RokkoLayout.canvas.width, height: RokkoLayout.canvas.height)
        }
    }
}
