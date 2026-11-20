//
//  PreviewSupport.swift
//  Xcode canvas only (DEBUG). Helpers so every screen and game scene can have a `#Preview`:
//  open a file, press ⌥⌘↩ to show the canvas, edit the code, the preview updates.
//
//  - `ExerciseRoundPreview`: one real pool round in the real lesson frame (no DEV badge).
//    Taps and drags work in the canvas (use Live mode), Again rebuilds the round.
//  - `SpriteNodePreview`: a bare SpriteKit scene for looking at single nodes (cards, slots, art).
//  - `PreviewData`: an in-memory SwiftData store for screens that need `AppSettings`.
//
//  Never shipped: everything here is inside `#if DEBUG`.
//

#if DEBUG
import SwiftUI
import SwiftData
import SpriteKit
import RokkoContent
import RokkoEngine

// MARK: - One exercise round

/// One round from `exercise_pool.json`, played in the lesson frame exactly as the child sees it.
/// - code: exercise code `LLL-M-TT-EE` (e.g. "001-1-01-01").
/// - level: 1–6. index: which round of that level (0 = first).
struct ExerciseRoundPreview: View {
    let code: String
    let level: Int
    var index = 0
    var calm = false

    @State private var controller: RoundController?
    @State private var problem: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch ContentLibrary.shared {
        case .failure(let error):
            Text(error.description).padding()
        case .success(let library):
            DesignCanvas(background: RokkoColor.paper, fills: true) {
                LessonFrame(surface: .child(calm: calm),
                            pathDone: 0,
                            pathTotal: 0,
                            caption: controller?.caption,
                            next: LessonNextButton(kind: .next, enabled: true),
                            showsAgain: true,
                            onAgain: { build(library) }) {
                    if let controller {
                        GameHost(scene: controller.scene)
                            .frame(width: RokkoLayout.canvas.width, height: RokkoLayout.canvas.height)
                    } else if let problem {
                        Text(problem)
                            .font(RokkoFont.nunito(24, .bold))
                            .foregroundStyle(RokkoColor.ink)
                            .frame(width: RokkoLayout.canvas.width, height: RokkoLayout.canvas.height)
                    }
                }
            }
            .onAppear { if controller == nil { build(library) } }
            .onDisappear { controller?.stop() }
        }
    }

    private func build(_ library: ContentLibrary) {
        guard let exercise = library.pool.exercise(code) else {
            problem = "No exercise \(code) in exercise_pool.json"
            return
        }
        let rounds = exercise.rounds(level: level)
        guard rounds.indices.contains(index) else {
            problem = "\(code) level \(level) has \(rounds.count) round(s); no round \(index + 1)"
            return
        }
        controller?.stop()
        let spec = library.generator.spec(for: rounds[index], type: exercise.type, previousAnswerSlot: nil)
        let motion = SceneMotion(library.config, calm: calm, reduceMotion: reduceMotion)
        let idle = HintLadder.idleSeconds(library.config.hints, calmOrWobbly: calm)
        controller = RoundController(spec: spec, library: library, motion: motion, idleSeconds: idle)
    }
}

// MARK: - Bare SpriteKit nodes

/// A plain scene (design points, top-left origin via `design`) for previewing nodes on their own.
struct SpriteNodePreview: View {
    var size = CGSize(width: 1194, height: 500)
    var calm = false
    /// Add nodes to the scene. `design(x, y)` converts top-left design points to scene points.
    let build: (_ scene: SKScene, _ motion: SceneMotion, _ design: (CGFloat, CGFloat) -> CGPoint) -> Void

    @State private var scene: SKScene?

    var body: some View {
        ZStack {
            RokkoColor.paper.ignoresSafeArea()
            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .aspectRatio(size, contentMode: .fit)
            }
        }
        .onAppear {
            guard scene == nil, case .success(let library) = ContentLibrary.shared else { return }
            let s = SKScene(size: size)
            s.scaleMode = .aspectFit
            s.backgroundColor = .clear
            let motion = SceneMotion(library.config, calm: calm, reduceMotion: false)
            let h = size.height
            build(s, motion) { x, y in CGPoint(x: x, y: h - y) }
            scene = s
        }
    }

    /// A small caption under a node.
    static func label(_ text: String, at point: CGPoint) -> SKLabelNode {
        let l = SKLabelNode(text: text)
        l.fontName = "Fredoka-SemiBold"
        l.fontSize = 18
        l.fontColor = RokkoColor.ui(RokkoColor.inkSoft)
        l.verticalAlignmentMode = .center
        l.position = point
        return l
    }
}

// MARK: - SwiftData

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(Store.models),
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Preview store: \(error)")
        }
    }()

    static func settings(calm: Bool = true) -> AppSettings {
        let s = AppSettings()
        s.calm = calm
        container.mainContext.insert(s)
        return s
    }
}
#endif
