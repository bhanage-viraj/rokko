//
//  ExercisePlayerView.swift
//  Plays pool rounds in the real lesson frame (developer access). Next = next round in the pool
//  (on to the next level after the last round), Again = the same round from the start,
//  Pause = back to the exercise list. A small DEV badge shows the round code, the hint step and
//  a BKT panel (P(known) per skill, the last evidence, the level BKT would pick); children never see it.
//

import SwiftUI
import RokkoContent
import RokkoEngine

struct ExercisePlayerView: View {
    let library: ContentLibrary
    let exercise: PoolExercise
    /// Saved Calm / Standard setting; the DEV badge can switch it mid-round.
    @Binding var calm: Bool
    let learner: DevLearner
    let onClose: () -> Void
    /// UI/UX check: replaces the built-in Next (next round in the pool) when set.
    private let onNext: (() -> Void)?
    /// UI/UX check: which layout this is, shown in the DEV badge.
    private let reviewLabel: String?

    @State private var bktShown = true

    @State private var level: Int
    @State private var index: Int
    @State private var controller: RoundController?
    /// Answer slot of the previous choice round, so the answer never sits in the same place twice.
    @State private var lastAnswerSlot: Int?
    /// The `lastAnswerSlot` this round was built with, so Again rebuilds it identically.
    @State private var slotForThisRound: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(library: ContentLibrary, exercise: PoolExercise, level: Int, index: Int, calm: Binding<Bool>, learner: DevLearner, onClose: @escaping () -> Void,
         onNext: (() -> Void)? = nil, reviewLabel: String? = nil) {
        self.onNext = onNext
        self.reviewLabel = reviewLabel
        self.library = library
        self.exercise = exercise
        _calm = calm
        self.learner = learner
        self.onClose = onClose
        let maxLevel = library.config.levels.maxLevel
        _level = State(initialValue: min(level, maxLevel))
        _index = State(initialValue: level > maxLevel ? 0 : index)
    }

    private var rounds: [PoolRound] { exercise.rounds(level: level) }
    private var round: PoolRound? { rounds.indices.contains(index) ? rounds[index] : nil }

    var body: some View {
        DesignCanvas(background: RokkoColor.paper, fills: true) {
            LessonFrame(surface: .child(calm: calm),
                        pathDone: 0,
                        pathTotal: 0,
                        caption: controller?.caption,
                        next: LessonNextButton(kind: .next, enabled: true),
                        showsAgain: true,
                        onPause: onClose,
                        onNext: { if let onNext { onNext() } else { next() } },
                        onAgain: { build(previousSlot: slotForThisRound) }) {
                if let controller {
                    GameHost(scene: controller.scene)
                        .frame(width: RokkoLayout.canvas.width, height: RokkoLayout.canvas.height)
                }
            }
            .overlay(alignment: .top) { devBadge.padding(.top, 36) }
            .overlay(alignment: .topLeading) {
                if bktShown { bktPanel.padding(.top, 96).padding(.leading, 24) }
            }
        }
        .onAppear { if controller == nil { build(previousSlot: nil) } }
        .onDisappear { controller?.stop() }
        .onChange(of: calm) { build(previousSlot: slotForThisRound) }
    }

    private var devBadge: some View {
        HStack(spacing: 10) {
            Text("DEV").font(RokkoFont.nunito(14, .black)).foregroundStyle(RokkoColor.card)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(RokkoColor.teal))
            Text(round?.id ?? exercise.code).font(.system(size: 17, weight: .semibold, design: .monospaced))
            if let reviewLabel {
                Text(reviewLabel).font(RokkoFont.nunito(17, .bold))
            } else {
                Text("Level \(level) · round \(index + 1) of \(rounds.count)")
                    .font(RokkoFont.nunito(17, .bold))
            }
            if let step = controller?.hintStep, step != .none {
                Text("Hint \(step.rawValue)").font(RokkoFont.nunito(15, .heavy))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(RokkoColor.honeyWash))
                    .overlay(Capsule().stroke(RokkoColor.honey, lineWidth: 2))
            }
            if controller?.isFinished == true {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(RokkoColor.moss)
            }
            Button(bktShown ? "Hide BKT" : "BKT") { bktShown.toggle() }
                .font(RokkoFont.nunito(15, .bold))
            LookPicker(calm: $calm)
        }
        .foregroundStyle(RokkoColor.ink)
        .accessibilityElement(children: .contain)
    }

    /// DEV only: what BKT knows. Never shown to the child.
    private var bktPanel: some View {
        let l = learner.learner
        let last = l.log.last
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BKT · P(known)").font(RokkoFont.nunito(15, .heavy))
                Spacer()
                Button("Reset BKT") { learner.reset() }.font(RokkoFont.nunito(14, .bold))
                Button("Reset exercise") { resetExercise() }.font(RokkoFont.nunito(14, .bold))
            }
            ForEach(Skill.allCases, id: \.self) { skill in
                let p = l.known(skill)
                HStack(spacing: 8) {
                    Text(skill.rawValue).frame(width: 92, alignment: .leading)
                    ProgressView(value: p).tint(p >= library.config.levels.mastered ? RokkoColor.moss : RokkoColor.teal)
                        .frame(width: 90)
                    Text(p.formatted(.number.precision(.fractionLength(2)))).monospacedDigit()
                }
                .font(RokkoFont.nunito(14, last?.result.skill == skill ? .heavy : .semibold))
            }
            Divider()
            if let last {
                Text("Last: \(last.result.skill.rawValue), \(Self.describe(last.evidence))")
                Text("\(last.before.formatted(.number.precision(.fractionLength(3)))) → \(last.after.formatted(.number.precision(.fractionLength(3))))")
                    .monospacedDigit()
            } else {
                Text("No answers yet")
            }
            Text("BKT would pick level \(learner.suggestedLevel(for: exercise, lastLevel: level)) next")
        }
        .font(RokkoFont.nunito(14, .semibold))
        .foregroundStyle(RokkoColor.ink)
        .padding(14)
        .frame(width: 250, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(RokkoColor.card.opacity(0.95)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RokkoColor.cardEdge, lineWidth: 2))
    }

    private static func describe(_ e: Evidence) -> String {
        func g(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(2))) }
        switch e {
        case .correct(let guess): return "correct (G \(g(guess)))"
        case .incorrect(let guess): return "not known (G \(g(guess)))"
        case .ignored(.afterArrow): return "no update (right after arrow)"
        case .ignored(.fastTap): return "no update (too fast)"
        }
    }

    private func build(previousSlot: Int?) {
        guard let round else { return }
        controller?.stop()
        let spec = library.generator.spec(for: round, type: exercise.type, previousAnswerSlot: previousSlot)
        let motion = SceneMotion(library.config, calm: calm, reduceMotion: reduceMotion)
        slotForThisRound = previousSlot
        if case .choice(let c) = spec.body { lastAnswerSlot = c.answerSlot }
        let idle = HintLadder.idleSeconds(library.config.hints, calmOrWobbly: calm)
        let learner = learner
        controller = RoundController(spec: spec, library: library, motion: motion, idleSeconds: idle,
                                     onResult: { learner.record($0) })
    }

    /// Levels that are on (never above EngineConfig › levels.maxLevel).
    private var playableLevels: [Int] { exercise.playableLevels(maxLevel: library.config.levels.maxLevel) }

    /// Next round; after the last round of the highest level that is on, the exercise resets to
    /// level 1, round 1 with a fresh BKT.
    private func next() {
        if index + 1 < rounds.count {
            index += 1
        } else if let nextLevel = playableLevels.first(where: { $0 > level }) {
            level = nextLevel
            index = 0
        } else {
            resetExercise()
            return
        }
        build(previousSlot: lastAnswerSlot)
    }

    private func resetExercise() {
        level = playableLevels.first ?? 1
        index = 0
        lastAnswerSlot = nil
        learner.reset()
        build(previousSlot: nil)
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)
// With the DEV badge and BKT panel. For the clean child view use the previews in Scenes/*.swift.

#if DEBUG
#Preview("Exercise player · Type 1 L1 (DEV)", traits: .landscapeLeft) {
    @Previewable @State var calm = false
    if case .success(let library) = ContentLibrary.shared, let ex = library.pool.exercise("001-1-01-01") {
        ExercisePlayerView(library: library, exercise: ex, level: 1, index: 0, calm: $calm,
                           learner: DevLearner(config: library.config), onClose: {})
    }
}
#endif
