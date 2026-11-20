//
//  LessonMapView.swift
//  Guardian home (hi-fi canvas 04). Lesson 1 is open; Lessons 2–3 are "Coming soon" (FR-05).
//

import SwiftUI
import SwiftData

struct LessonMapView: View {
    @Bindable var settings: AppSettings
    let onStartLesson: () -> Void

    /// DEBUG: `-RokkoOpenSettings YES` opens the Guardian menu on launch.
    @State private var menuShown = UserDefaults.standard.bool(forKey: "RokkoOpenSettings")
    /// Developer exercise browser. DEBUG: `-RokkoOpenExercises YES` opens it on launch.
    @State private var exercisesShown = UserDefaults.standard.bool(forKey: "RokkoOpenExercises")
    /// Developer UI/UX check (one round per layout). DEBUG: `-RokkoOpenUIReview YES` opens it on launch.
    @State private var uiReviewShown = UserDefaults.standard.bool(forKey: "RokkoOpenUIReview")

    var body: some View {
        DesignCanvas(fills: true) {
            HomeLayout(onSettings: { menuShown = true }, onStartLesson: onStartLesson)
        }
        .sheet(isPresented: $menuShown) {
            GuardianMenu(settings: settings,
                         onClose: { menuShown = false })
        }
        .fullScreenCover(isPresented: $exercisesShown) {
            DeveloperExercisesView(calm: $settings.calm) { exercisesShown = false }
        }
        .fullScreenCover(isPresented: $uiReviewShown) {
            UIReviewView(calm: $settings.calm) { uiReviewShown = false }
        }
    }
}

/// One lesson on the home carousel.
private struct HomeLesson: Identifiable {
    let number: Int
    let title: String
    let detail: String
    let objectives: [String]
    let open: Bool
    var id: Int { number }

    static let all: [HomeLesson] = [
        HomeLesson(number: 1, title: "The Day the Jungle Changed",
                   detail: "Meet six animals and their chess pieces.",
                   objectives: ["Meet the 6 chess pieces",
                                "Learn what each piece represents",
                                "Start your chess adventure"],
                   open: true),
        HomeLesson(number: 2, title: "The Magical Sixty-Four Squares",
                   detail: "Light and dark squares, lines and corners.",
                   objectives: ["Light and dark squares",
                                "Rows, columns and corners",
                                "Set up the board together"],
                   open: false),
        HomeLesson(number: 3, title: "The Lion Who Must Never Fall",
                   detail: "How the king moves and stays safe.",
                   objectives: ["How the king moves",
                                "Keeping the king safe",
                                "Play a first king game"],
                   open: false),
    ]
}

/// Fills the whole screen: title, All Lessons and Settings across the top; one wide lesson card
/// in the middle with the next one peeking in; page dots below. Swipe or tap › to move.
private struct HomeLayout: View {
    let onSettings: () -> Void
    let onStartLesson: () -> Void
    @Environment(\.canvasSize) private var canvas
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rokkoCalm) private var calm
    @State private var focused: Int? = 1
    @State private var listShown = false

    private let side: CGFloat = 56
    private let top: CGFloat = 156
    private let gap: CGFloat = 28

    private var lessons: [HomeLesson] { HomeLesson.all }
    private var current: Int { focused ?? 1 }

    var body: some View {
        let cardWidth = (canvas.width * 0.66).rounded()
        let cardHeight = min(canvas.height - top - 96, cardWidth * 0.72).rounded()
        let inset = (canvas.width - cardWidth) / 2
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                GuardianLabel(text: "For the Guardian")
                GuardianTitle(text: "Your lessons")
            }
            .offset(x: side, y: 40)

            HStack(spacing: 16) {
                Button { listShown = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "list.bullet").font(.system(size: 20, weight: .bold))
                        Text("All Lessons").font(RokkoFont.fredoka(20))
                    }
                    .foregroundStyle(RokkoColor.ink)
                    .padding(.horizontal, 24)
                    .frame(height: 56)
                    .background(Capsule().fill(RokkoColor.card))
                    .overlay(Capsule().strokeBorder(RokkoColor.mistEdge, lineWidth: 2))
                }
                .buttonStyle(PressScaleStyle())
                GuardianIconButton(systemName: "gearshape.fill", label: "Settings", action: onSettings)
            }
            .frame(width: canvas.width - 40, alignment: .trailing)
            .offset(y: 26)

            ScrollView(.horizontal) {
                HStack(spacing: gap) {
                    ForEach(lessons) { lesson in
                        LessonCard(lesson: lesson, width: cardWidth, height: cardHeight,
                                   action: onStartLesson)
                            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                view.scaleEffect(phase.isIdentity ? 1 : 0.84)
                                    .opacity(phase.isIdentity ? 1 : 0.7)
                            }
                            .id(lesson.number)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 14)   // room for the card shadow
            }
            .contentMargins(.horizontal, inset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focused)
            .scrollIndicators(.hidden)
            .frame(width: canvas.width, height: cardHeight + 28)
            .offset(y: top - 14)

            // ‹ and › sit in the gaps beside the middle card.
            HStack {
                ArrowButton(systemName: "chevron.left", label: "Previous lesson") { move(-1) }
                    .opacity(current > 1 ? 1 : 0)
                    .disabled(current <= 1)
                Spacer()
                ArrowButton(systemName: "chevron.right", label: "Next lesson") { move(1) }
                    .opacity(current < lessons.count ? 1 : 0)
                    .disabled(current >= lessons.count)
            }
            .frame(width: cardWidth + gap + 56)
            .offset(x: inset - (gap + 56) / 2, y: top + cardHeight / 2 - 28)

            PageDots(count: lessons.count, current: current) { go(to: $0) }
                .frame(width: canvas.width)
                .offset(y: top + cardHeight + 34)
        }
        .sheet(isPresented: $listShown) {
            AllLessonsSheet(lessons: lessons, current: current) { number in
                listShown = false
                go(to: number)
            }
        }
    }

    private func move(_ step: Int) {
        go(to: min(max(current + step, 1), lessons.count))
    }

    private func go(to number: Int) {
        if reduceMotion || calm {
            focused = number
        } else {
            withAnimation(.easeInOut(duration: RokkoMotion.screenFade)) { focused = number }
        }
    }
}

private struct ArrowButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(RokkoColor.leaf)
                .frame(width: 56, height: 56)
                .background(Circle().fill(RokkoColor.card)
                    .shadow(color: RokkoColor.ink.opacity(0.12), radius: 6, y: 3))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(1...count, id: \.self) { n in
                Button { select(n) } label: {
                    Circle()
                        .fill(n == current ? RokkoColor.leaf : RokkoColor.mistTrack)
                        .frame(width: 14, height: 14)
                        .frame(width: 32, height: 32)   // touch target
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lesson \(n)")
                .accessibilityAddTraits(n == current ? .isSelected : [])
            }
        }
    }
}

private struct AllLessonsSheet: View {
    let lessons: [HomeLesson]
    let current: Int
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GuardianTitle(text: "All lessons")
                .padding(.bottom, 8)
            ForEach(lessons) { lesson in
                Button { select(lesson.number) } label: {
                    HStack(spacing: 18) {
                        Text("\(lesson.number)")
                            .font(RokkoFont.fredoka(24))
                            .foregroundStyle(lesson.open ? RokkoColor.card : RokkoColor.teal)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(lesson.open ? RokkoColor.leaf : RokkoColor.tealWash))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title).font(RokkoFont.fredoka(22, scales: true))
                                .foregroundStyle(RokkoColor.ink)
                            Text(lesson.open ? lesson.detail : "Coming soon")
                                .font(RokkoFont.nunito(17, .semibold, scales: true))
                                .foregroundStyle(RokkoColor.inkSoft)
                        }
                        Spacer(minLength: 0)
                        if lesson.number == current {
                            Image(systemName: "checkmark").font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(RokkoColor.teal)
                                .accessibilityLabel("Showing")
                        }
                    }
                    .padding(16)
                    .rokkoCard(radius: 22, edge: RokkoColor.mistEdgeSoft, edgeWidth: 2)
                }
                .buttonStyle(PressScaleStyle())
            }
            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RokkoColor.mistBlue)
        .presentationDetents([.medium])
    }
}

private struct LessonCard: View {
    let lesson: HomeLesson
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        let inner: CGFloat = 18
        let artSide = height - inner * 2
        HStack(spacing: 0) {
            art
                .frame(width: min(artSide, width * 0.48), height: artSide)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(inner)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                Text("LESSON \(lesson.number)")
                    .font(RokkoFont.nunito(15, .black))
                    .tracking(1.4)
                    .foregroundStyle(RokkoColor.teal)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(RokkoColor.tealWash))
                Text(lesson.title)
                    .font(RokkoFont.fredoka(36, scales: true))
                    .foregroundStyle(RokkoColor.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(lesson.detail)
                    .font(RokkoFont.nunito(20, .semibold, scales: true))
                    .foregroundStyle(RokkoColor.inkSoft)
                    .minimumScaleFactor(0.7)
                Text("LEARNING OBJECTIVES")
                    .font(RokkoFont.nunito(14, .black))
                    .tracking(1.4)
                    .foregroundStyle(RokkoColor.leaf)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(RokkoColor.sageWash))
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(lesson.objectives, id: \.self) { goal in
                        Label {
                            Text(goal).font(RokkoFont.nunito(20, .semibold, scales: true))
                                .foregroundStyle(RokkoColor.ink)
                                .minimumScaleFactor(0.7)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(RokkoColor.moss)
                        }
                    }
                }
                Spacer(minLength: 0)
                Group {
                    if lesson.open {
                        PrimaryButton(title: "Start", height: 60, fontSize: 22, cornerRadius: 30, action: action)
                            .accessibilityIdentifier("lessonMap.start.\(lesson.number)")
                    } else {
                        Text("Coming soon")
                            .font(RokkoFont.fredoka(20, scales: true))
                            .foregroundStyle(RokkoColor.inkSoft)
                            .padding(.horizontal, 40)
                            .frame(minHeight: 60)
                            .background(Capsule().fill(RokkoColor.tealWash))
                            .accessibilityLabel("Lesson \(lesson.number), coming soon")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 28)
            .padding(.trailing, 32)
            .padding(.leading, 8)
        }
        .frame(width: width, height: height)
        .rokkoCard(radius: 36, edge: lesson.open ? RokkoColor.leaf : RokkoColor.mistEdge,
                   edgeWidth: lesson.open ? 4 : 3)
    }

    @ViewBuilder private var art: some View {
        switch lesson.number {
        case 1:
            ZStack {
                Image("bg_clearing").resizable().scaledToFill()
                Image(Animal.lion.imageName).resizable().scaledToFit()
                    .padding(.horizontal, 40).padding(.vertical, 50)
                    .offset(y: 20)
            }
        case 2:
            ZStack {
                RokkoColor.sageWash
                Image("prop_board").resizable().scaledToFit().padding(36)
            }
        default:
            ZStack {
                RokkoColor.sageWash
                Image("piece_king_ivory").resizable().scaledToFit().padding(.vertical, 40)
            }
        }
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Lesson map", traits: .landscapeLeft) {
    LessonMapView(settings: PreviewData.settings(), onStartLesson: {})
        .modelContainer(PreviewData.container)
}
#endif
