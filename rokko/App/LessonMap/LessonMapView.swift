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
    @State private var menuShown = DebugFlag.on("RokkoOpenSettings")
    /// Developer exercise browser. DEBUG: `-RokkoOpenExercises YES` opens it on launch.
    @State private var exercisesShown = DebugFlag.on("RokkoOpenExercises")
    /// Developer UI/UX check (one round per layout). DEBUG: `-RokkoOpenUIReview YES` opens it on launch.
    @State private var uiReviewShown = DebugFlag.on("RokkoOpenUIReview")

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

/// Fills the whole screen: title and Settings across the top; one wide lesson card
/// in the middle with the next one peeking in; page dots below. Swipe or tap a dot to move.
/// Behind the cards each lesson has its own scenery (`HomeScenery`), which follows the finger
/// at a slower speed than the cards for depth.
private struct HomeLayout: View {
    let onSettings: () -> Void
    let onStartLesson: () -> Void
    @Environment(\.canvasSize) private var canvas
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rokkoCalm) private var calm
    @State private var focused: Int? = 1
    /// Written on every scroll frame; only `HomeScenery` reads it, so this body doesn't re-run.
    @State private var progress = HomeScrollProgress()
    @MotionStill private var still

    private let side: CGFloat = 56
    private let top: CGFloat = 156
    private let gap: CGFloat = 28

    private var lessons: [HomeLesson] { HomeLesson.all }
    private var current: Int { focused ?? 1 }

    var body: some View {
        let cardWidth = (canvas.width * 0.66).rounded()
        let cardHeight = min(canvas.height - top - 96, cardWidth * 0.72).rounded()
        let inset = (canvas.width - cardWidth) / 2
        let pageWidth = cardWidth + gap
        ZStack(alignment: .topLeading) {
            HomeScenery(progress: progress, lessonNumbers: lessons.map(\.number), pageWidth: pageWidth)

            VStack(alignment: .leading, spacing: 10) {
                GuardianLabel(text: "Guardian")
                GuardianTitle(text: "Your lessons")
            }
            .offset(x: side, y: 40)

            GuardianIconButton(systemName: "gearshape.fill", label: "Settings", action: onSettings)
                .frame(width: canvas.width - 40, alignment: .trailing)
            .offset(y: 26)

            ScrollView(.horizontal) {
                HStack(spacing: gap) {
                    ForEach(lessons) { lesson in
                        LessonCard(lesson: lesson, width: cardWidth, height: cardHeight,
                                   restMinX: inset, pageWidth: pageWidth, still: still,
                                   action: onStartLesson)
                            // Neighbours sit slightly smaller and quieter, but stay solid: a see-through
                            // card lets the scenery show through its text.
                            .scrollTransition(.interactive, axis: .horizontal) { [still] view, phase in
                                view.scaleEffect(phase.isIdentity || still ? 1 : 0.92)
                                    .saturation(phase.isIdentity ? 1 : 0.75)
                            }
                            .id(lesson.number)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 14)   // room for the card shadow
            }
            .contentMargins(.horizontal, inset, for: .scrollContent)
            // One lesson per swipe however fast the flick; short or mostly-vertical drags snap back.
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $focused)
            // Live offset (finger, momentum and the page-dot animation) → scenery position.
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.x + geo.contentInsets.leading
            } action: { [progress] _, x in
                progress.page = x / pageWidth
            }
            .scrollIndicators(.hidden)
            .frame(width: canvas.width, height: cardHeight + 28)
            .offset(y: top - 14)

            // Page dots centred under the cards (HIG page control). Swipe or tap a dot to move.
            PageDots(count: lessons.count, current: current) { go(to: $0) }
                .frame(width: canvas.width)
                .offset(y: top + cardHeight + 30)
        }
        #if DEBUG
        // `-RokkoHomeLesson 2` opens the carousel on that lesson (screenshots). Set after the first
        // layout: a scroll position set before the scroll view exists is ignored.
        .task {
            let n = UserDefaults.standard.integer(forKey: "RokkoHomeLesson")
            if n > 1, n <= lessons.count { focused = n }
        }
        #endif
    }

    private func go(to number: Int) {
        if reduceMotion || calm {
            focused = number
        } else {
            withAnimation(.easeInOut(duration: RokkoMotion.screenFade)) { focused = number }
        }
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

private struct LessonCard: View {
    let lesson: HomeLesson
    let width: CGFloat
    let height: CGFloat
    /// Card's left edge (scroll view space) when it is the one in the middle.
    let restMinX: CGFloat
    /// One swipe: the distance between two cards.
    let pageWidth: CGFloat
    /// Calm / Reduce Motion: no parallax inside the picture.
    let still: Bool
    let action: () -> Void

    var body: some View {
        let inner: CGFloat = 18
        let artSide = height - inner * 2
        let artWidth = min(artSide, width * 0.54)
        HStack(spacing: 0) {
            art(width: artWidth, restMidX: restMinX + inner + artWidth / 2)
                .frame(width: artWidth, height: artSide)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(inner)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 16) {
                Spacer(minLength: 0)
                Text(lesson.title)
                    .font(RokkoFont.fredoka(40, scales: true))
                    .foregroundStyle(RokkoColor.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(lesson.detail)
                    .font(RokkoFont.nunito(20, .semibold, scales: true))
                    .foregroundStyle(RokkoColor.inkSoft)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
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
        // Lesson number in the card's top-right corner.
        .overlay(alignment: .topTrailing) {
            Text("LESSON \(lesson.number)")
                .font(RokkoFont.nunito(15, .black))
                .tracking(1.4)
                .foregroundStyle(RokkoColor.teal)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(RokkoColor.tealWash))
                .padding(.top, 28).padding(.trailing, 32)
        }
        .rokkoCard(radius: 36, edge: lesson.open ? RokkoColor.leaf : RokkoColor.mistEdge,
                   edgeWidth: lesson.open ? 4 : 3)
    }

    /// The picture's backdrop drifts a little against the card (`homeParallaxCardArt`) while the
    /// character moves with it, so the picture itself has depth.
    private func backdrop<V: View>(width: CGFloat, restMidX: CGFloat,
                                   @ViewBuilder _ content: () -> V) -> some View {
        let factor = still ? 0 : RokkoMotion.homeParallaxCardArt
        // Enough extra picture on each side to cover one full swipe of drift. Always the same size,
        // so switching Calm / Standard (or Reduce Motion) only stops the drift and never re-scales
        // the picture.
        let reach = pageWidth * RokkoMotion.homeParallaxCardArt
        return content()
            .frame(width: width + reach * 2)
            .visualEffect { [restMidX, factor, reach] view, proxy in
                // How far the picture is from where it sits when its card is centred.
                let moved = proxy.frame(in: .scrollView(axis: .horizontal)).midX - restMidX
                return view.offset(x: max(-reach, min(reach, -moved * factor)))
            }
            .frame(width: width)
            .clipped()
    }

    @ViewBuilder private func art(width: CGFloat, restMidX: CGFloat) -> some View {
        switch lesson.number {
        case 1:
            ZStack {
                backdrop(width: width, restMidX: restMidX) { Image("bg_clearing").resizable().scaledToFill() }
                // Smaller lion standing on the path, so the clearing around him shows.
                Image(Animal.lion.imageName).resizable().scaledToFit()
                    .frame(width: width * 0.6)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 56)
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
