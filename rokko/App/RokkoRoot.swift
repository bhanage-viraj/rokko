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
                                  onStartLesson: { show(.lesson) })
                        .transition(.opacity)
                }
            case .lesson:
                if let settings, case .success(let library) = ContentLibrary.shared {
                    LessonContainer(coordinator: LessonCoordinator(library: library, settings: settings, context: context,
                                                                   onExit: { show(.lessonMap) }))
                        .transition(.opacity)
                } else {
                    LessonPlaceholderView { show(.lessonMap) }
                        .transition(.opacity)
                }
            }
        }
        .environment(\.rokkoCalm, settings?.calm ?? false)
        .onAppear {
            settings = Store.settings(in: context)
            #if DEBUG
            // `-RokkoLook standard|calm` sets the look on launch (screenshots).
            switch UserDefaults.standard.string(forKey: "RokkoLook") {
            case "standard": settings?.calm = false
            case "calm": settings?.calm = true
            default: break
            }
            #endif
        }
    }

    private var screenAfterLaunch: Screen {
        #if DEBUG
        // `-RokkoScreen lessonMap` / `-RokkoOnboardingStep <step>` jump straight there.
        if UserDefaults.standard.string(forKey: "RokkoScreen") == "lessonMap" { return .lessonMap }
        if UserDefaults.standard.string(forKey: "RokkoScreen") == "lesson" { return .lesson }
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

/// Shown only if the bundled content cannot be read (ContentValidationTests catch that first).
private struct LessonPlaceholderView: View {
    let onBack: () -> Void

    var body: some View {
        DesignCanvas(background: RokkoColor.paper) {
            VStack(spacing: 24) {
                Text("Lesson 1 could not open")
                    .font(RokkoFont.fredoka(44))
                    .foregroundStyle(RokkoColor.ink)
                Text("The lesson files are missing.")
                    .font(RokkoFont.nunito(21))
                    .foregroundStyle(RokkoColor.inkSoft)
                SecondaryButton(title: "Back to lessons", action: onBack)
                    .frame(width: 320)
            }
            .frame(width: RokkoLayout.canvas.width, height: RokkoLayout.canvas.height)
        }
    }
}
