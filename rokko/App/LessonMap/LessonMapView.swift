//
//  LessonMapView.swift
//  Guardian home (hi-fi canvas 04). Lesson 1 is open; Lessons 2–3 are "Coming soon" (FR-05).
//

import SwiftUI

struct LessonMapView: View {
    @Bindable var settings: AppSettings
    let onStartLesson: () -> Void
    let onRunSetupAgain: () -> Void

    /// DEBUG: `-RokkoOpenSettings YES` opens the Guardian menu on launch.
    @State private var menuShown = UserDefaults.standard.bool(forKey: "RokkoOpenSettings")

    var body: some View {
        DesignCanvas {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    GuardianLabel(text: "For the Guardian")
                    GuardianTitle(text: "Your lessons")
                }
                .offset(x: 64, y: 52)

                // Top-right corner, same spot and style as Skip in first-run setup.
                GuardianIconButton(systemName: "gearshape.fill", label: "Settings") { menuShown = true }
                    .offset(x: 1194 - 40 - 56, y: 26)

                HStack(spacing: 24) {
                    LessonCard(number: 1,
                               title: "The Day the Jungle Changed",
                               detail: "Meet six animals and their chess pieces.",
                               open: true,
                               action: onStartLesson) {
                        ZStack {
                            Image("bg_clearing").resizable().scaledToFill()
                            Image(Animal.lion.imageName).resizable().scaledToFit().frame(width: 150, height: 160)
                        }
                    }
                    LessonCard(number: 2,
                               title: "The Magical Sixty-Four Squares",
                               detail: "Light and dark squares, lines and corners.",
                               open: false, action: {}) {
                        ZStack {
                            RokkoColor.sageWash
                            Image("prop_board").resizable().scaledToFit().frame(width: 200, height: 200)
                        }
                    }
                    LessonCard(number: 3,
                               title: "The Lion Who Must Never Fall",
                               detail: "How the king moves and stays safe.",
                               open: false, action: {}) {
                        ZStack {
                            RokkoColor.sageWash
                            Image("piece_king_ivory").resizable().scaledToFit().frame(width: 80, height: 190)
                        }
                    }
                }
                .offset(x: 64, y: 200)
            }
        }
        .sheet(isPresented: $menuShown) {
            GuardianMenu(settings: settings,
                         onRunSetupAgain: { menuShown = false; onRunSetupAgain() },
                         onClose: { menuShown = false })
        }
    }
}

private struct LessonCard<Art: View>: View {
    let number: Int
    let title: String
    let detail: String
    let open: Bool
    let action: () -> Void
    @ViewBuilder var art: () -> Art

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            art()
                .frame(width: 338, height: 220)
                .clipped()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("LESSON \(number)")
                    .font(RokkoFont.nunito(15, .black, scales: true))
                    .tracking(1.2)
                    .foregroundStyle(RokkoColor.teal)
                Text(title).font(RokkoFont.fredoka(24, scales: true)).foregroundStyle(RokkoColor.ink)
                Text(detail).font(RokkoFont.nunito(17, .semibold, scales: true)).foregroundStyle(RokkoColor.inkSoft)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            Spacer(minLength: 0)
            Group {
                if open {
                    PrimaryButton(title: "Start", height: 58, fontSize: 20, cornerRadius: 29, action: action)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Coming soon")
                        .font(RokkoFont.fredoka(20, scales: true))
                        .foregroundStyle(RokkoColor.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Capsule().fill(RokkoColor.tealWash))
                        .accessibilityLabel("Lesson \(number), coming soon")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(width: 338, height: 470)
        .rokkoCard(edge: open ? RokkoColor.leaf : RokkoColor.mistEdge, edgeWidth: open ? 4 : 3)
    }
}
