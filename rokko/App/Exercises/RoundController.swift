//
//  RoundController.swift
//  The view model for one round. Scenes report taps and drops; this decides right or wrong,
//  sends Feedback back, sets the caption, and locks input while feedback and hints play.
//
//  Hint ladder (docs/ENGINE.md §5): a wrong answer after the free try(s) moves one step up. Idle
//  hints are off by default (the Guardian explains first); when on, idle stops at the arrow.
//    1 clue card (animal half + piece half)  ·  "Look at this. The lion has a cross on its crown. The King has a cross too."
//    2 arrow on the right answer / slot  ·  "Look here." + question
//    3 the answer shows itself  ·  "This is the King."  (choice rounds end; drag games place that figure)
//  The ladder resets for every target (choice: the round; drags: each link or figure).
//
//  Each finished target becomes a `TargetResult` for BKT (`onResult`); the Learner applies the evidence rules.
//

import Foundation
import Observation
import RokkoContent
import RokkoEngine

@MainActor
@Observable
final class RoundController: GameSceneDelegate {
    enum Outcome: Equatable { case right, tryAgain }

    let spec: RoundSpec
    /// Caption text: always the exact recorded line(s) for the current voice key(s).
    private(set) var caption: String?
    private(set) var isFinished = false
    /// Current hint step for the active target.
    private(set) var hintStep: HintStep = .none
    /// Every answer in order (not shown to anyone).
    private(set) var answers: [(target: Piece, outcome: Outcome)] = []
    /// Every finished target, as sent to BKT.
    private(set) var results: [TargetResult] = []

    @ObservationIgnored private let library: ContentLibrary
    @ObservationIgnored private(set) var scene: LessonScene!
    @ObservationIgnored private var motion: SceneMotion
    @ObservationIgnored private let onResult: ((TargetResult) -> Void)?

    // Round state
    @ObservationIgnored private var wrongCards = Set<String>()
    @ObservationIgnored private var links: [String: Set<String>] = [:]          // Type 3: character → linked pieces
    @ObservationIgnored private var part = 0
    /// Cheer said before a right answer or a finished game; changes every time (same round → same order).
    @ObservationIgnored private var cheers: CheerPicker
    /// Type 3: the link the child last tried and missed (and which card they dragged), so the hints
    /// help with that pair, not just the first unlinked pair on screen.
    @ObservationIgnored private var linkFocus: (dragged: String, character: String, piece: String)?
    @ObservationIgnored private var filled: [String: Item] = [:]                // Types 4 · 5: slot → figure
    @ObservationIgnored private var placedFigures = Set<String>()
    @ObservationIgnored private var batch = 0

    // Hints
    @ObservationIgnored private var ladder: HintLadder
    @ObservationIgnored private var anyRevealed = false
    @ObservationIgnored private var targetStart = Date()
    @ObservationIgnored private let idleSeconds: Double?
    @ObservationIgnored private var idleTask: Task<Void, Never>?

    /// Tests: feedback finishes at once (no input lock, no waiting).
    @ObservationIgnored private let instantFeedback: Bool

    /// - idleSeconds: idle time before the next hint (12, or 18 in Calm / Wobbly). Nil = no idle hints (tests).
    init(spec: RoundSpec, library: ContentLibrary, motion: SceneMotion, idleSeconds: Double? = nil,
         instantFeedback: Bool = false, onResult: ((TargetResult) -> Void)? = nil) {
        self.spec = spec
        self.library = library
        self.motion = motion
        self.idleSeconds = idleSeconds
        self.instantFeedback = instantFeedback
        self.onResult = onResult
        ladder = HintLadder(freeTries: library.config.hints.freeTries)
        cheers = CheerPicker(seed: spec.id)
        scene = makeScene()
        scene.gameDelegate = self
        say(spec.introKey)
        restartIdle()
    }

    private func makeScene() -> LessonScene {
        let layout = library.config.layout
        switch spec.body {
        case .choice(let r): return ChoiceScene(round: r, level: spec.level, layout: layout, motion: motion)
        case .link(let r): return LinkScene(round: r, level: spec.level, layout: layout, motion: motion)
        case .shelf(let r):
            filled = r.prefilled
            return ShelfScene(round: r, motion: motion)
        case .teams(let r):
            filled = r.prefilled
            return TeamsScene(round: r, motion: motion)
        }
    }

    /// Stops the idle timer (the view is going away or the round is rebuilt).
    func stop() {
        idleTask?.cancel()
        idleTask = nil
        VoicePlayer.shared.stop()
    }

    private func say(_ keys: String...) { say(keys) }

    private func say(_ keys: [String]) {
        let lines = keys.compactMap { library.caption($0) }
        if !lines.isEmpty { caption = lines.joined(separator: " ") }
        VoicePlayer.shared.play(keys, gapSeconds: library.config.story.voiceGapMs / 1000)
    }

    /// Locks input for `seconds`, then runs `then`.
    private func lock(for seconds: TimeInterval, then: (() -> Void)? = nil) {
        if instantFeedback { then?(); return }
        scene.inputLocked = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self else { return }
            if !self.isFinished { self.scene.inputLocked = false }
            then?()
        }
    }

    /// - cheer: say a cheer from this pool first (nil after hint 3: the answer was shown, not found).
    private func finish(_ key: String, cheer pool: [String]? = nil) {
        isFinished = true
        scene.inputLocked = true
        stop()
        scene.show(.clearHints)
        if let pool { say(cheers.next(from: pool), key) } else { say(key) }
    }

    // MARK: Results and the ladder

    private var elapsedMs: Double { Date().timeIntervalSince(targetStart) * 1000 }

    /// A target is done (answered right, or shown by hint 3). Reports it and resets the ladder.
    private func resolve(_ skill: Skill, correct: Bool, guess: Double) {
        let result = TargetResult(skill: skill, correct: correct, hint: ladder.step, guess: guess,
                                  responseMs: correct ? elapsedMs : nil)
        report(result)
        ladder.reset()
        hintStep = .none
        targetStart = Date()
        scene.show(.clearHints)
    }

    private func report(_ result: TargetResult) {
        results.append(result)
        onResult?(result)
    }

    private func restartIdle() {
        idleTask?.cancel()
        guard let idleSeconds, !isFinished else { return }
        idleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(idleSeconds))
            guard !Task.isCancelled, let self, !self.isFinished else { return }
            if self.scene.inputLocked { self.restartIdle(); return }
            self.stepUp(.idle)
        }
    }

    /// One step up the ladder for the current target.
    private func stepUp(_ trigger: HintLadder.Trigger, support: String? = nil) {
        guard !isFinished, let target = hintTarget() else { return }
        let lead = support.map { [$0] } ?? []
        let before = ladder.step
        let step = ladder.stepUp(trigger)
        guard step != before else {
            if !lead.isEmpty { say(lead) }
            restartIdle()
            return
        }
        hintStep = step
        let hintLock = library.config.hints.lockMs / 1000
        switch step {
        case .none:
            break
        case .clue:
            scene.show(.clue(item: target.item, near: target.figure))
            say(VoiceKeys.hintClue(target.item.piece))
            lock(for: hintLock)
        case .arrow:
            scene.show(.arrow(at: target.destination))
            say(VoiceKeys.hintLookHere)
            lock(for: hintLock)
        case .reveal:
            anyRevealed = true
            reveal()
        }
        restartIdle()
    }

    /// What the hints point at: the figure to look at, and where the answer is.
    private func hintTarget() -> (item: Item, figure: String, destination: String)? {
        switch spec.body {
        case .choice(let r):
            return (r.cards[r.answerSlot].item, "shown", r.answerId)
        case .link(let r):
            guard let f = focusedLink(r) else { return nil }
            // Clue beside the card in the child's hand; arrow on the card it belongs on.
            let destination = f.dragged == f.character.id ? f.piece : f.character.id
            return (f.character.item, f.dragged, destination)
        case .shelf(let r):
            guard let (fig, slot) = nextShelfFigure(r) else { return nil }
            return (fig.item, fig.id, slot)
        case .teams(let r):
            guard let fig = nextTeamsFigure(r) else { return nil }
            return (fig.item, fig.id, fig.item.colour == .white ? TeamsScene.whiteHouse : TeamsScene.blackHouse)
        }
    }

    /// Hint 3: the answer shows itself and counts as not known.
    private func reveal() {
        switch spec.body {
        case .choice(let r):
            let answer = r.cards[r.answerSlot].item
            resolve(Skill(answer.piece), correct: false, guess: 1 / Double(r.cards.count))
            scene.show(.correct(r.answerId))
            scene.show(.dimAllExcept(r.answerId))
            finish(r.revealKey)
        case .link(let r):
            guard let f = focusedLink(r) else { return }
            completeLink(r, character: f.character, pieceId: f.piece, revealed: true)
        case .shelf(let r):
            guard let (fig, slot) = nextShelfFigure(r) else { return }
            placeOnShelf(r, figure: fig, slotId: slot, revealed: true)
        case .teams(let r):
            guard let fig = nextTeamsFigure(r) else { return }
            placeInHouse(r, figure: fig, revealed: true)
        }
    }

    // MARK: GameSceneDelegate

    func scene(_ scene: LessonScene, didReport event: InputEvent) {
        guard !isFinished else { return }
        if event == .touchBegan { restartIdle(); return }
        guard !scene.inputLocked else { return }
        switch spec.body {
        case .choice(let r): choice(r, event)
        case .link(let r): link(r, event)
        case .shelf(let r): shelf(r, event)
        case .teams(let r): teams(r, event)
        }
        restartIdle()
    }

    /// Wrong answer: soft feedback, then one hint step.
    /// A try that did not fit: soft feedback, a supporting line that changes each time, then one hint step.
    /// The support line is said on its own when no hint is due; when a hint is due, the hint is said instead.
    private func tryAgain(lockFor seconds: TimeInterval) {
        let support = cheers.next(from: VoiceKeys.encouragements)
        lock(for: seconds) { [weak self] in self?.stepUp(.wrongAnswer, support: support) }
    }

    // MARK: Types 1 · 2

    private func choice(_ r: ChoiceRound, _ event: InputEvent) {
        guard case .tap(let id) = event, !wrongCards.contains(id) else { return }
        let answer = r.cards[r.answerSlot].item
        if id == r.answerId {
            answers.append((answer.piece, .right))
            resolve(Skill(answer.piece), correct: true, guess: 1 / Double(r.cards.count))
            scene.show(.correct(id))
            scene.show(.dimAllExcept(id))
            finish(r.correctKey, cheer: VoiceKeys.cheers)
        } else {
            answers.append((answer.piece, .tryAgain))
            // Levels 5–6: picking the black twin also says Colour isn't known yet.
            if let picked = r.cards.first(where: { $0.id == id })?.item,
               picked.piece == answer.piece, picked.colour != answer.colour {
                report(TargetResult(skill: .colour, correct: false, hint: .none,
                                    guess: library.config.bkt.type5Guess, responseMs: nil))
            }
            wrongCards.insert(id)
            scene.show(.tryAgain(id))
            tryAgain(lockFor: motion.tryAgain)
        }
    }

    // MARK: Type 3

    /// First character in the current part still missing a link, and its next piece.
    private func nextLink(_ r: LinkRound) -> (Card, String)? {
        let current = r.parts[part]
        for ch in current.characters {
            let missing = (current.matches[ch.id] ?? []).subtracting(links[ch.id] ?? [])
            if let piece = missing.sorted().first { return (ch, piece) }
        }
        return nil
    }

    /// The pair the hints are about: the one the child last missed, if still unlinked; else the next unlinked pair.
    private func focusedLink(_ r: LinkRound) -> (dragged: String, character: Card, piece: String)? {
        let current = r.parts[part]
        if let f = linkFocus, let ch = current.characters.first(where: { $0.id == f.character }),
           !(links[ch.id] ?? []).contains(f.piece) {
            return (f.dragged, ch, f.piece)
        }
        guard let (ch, piece) = nextLink(r) else { return nil }
        return (ch.id, ch, piece)
    }

    /// A miss on a different pair is a new target: the ladder starts again for it.
    private func focus(_ new: (dragged: String, character: String, piece: String)?) {
        guard let new else { return }
        if let old = linkFocus, old.character == new.character, old.piece == new.piece {
            linkFocus = new
            return
        }
        if linkFocus != nil {
            ladder.reset()
            hintStep = .none
            scene.show(.clearHints)
        }
        linkFocus = new
    }

    private func link(_ r: LinkRound, _ event: InputEvent) {
        guard case .drop(let dropped, let target) = event else { return }
        let current = r.parts[part]
        // Either side can be dragged: a piece dropped on its character is the same link.
        let draggedPiece = current.pieces.contains { $0.id == dropped }
        let charId = draggedPiece ? target : dropped
        let otherEnd = draggedPiece ? dropped : target
        guard let charId, let character = current.characters.first(where: { $0.id == charId }),
              let pieceId = otherEnd else {
            scene.show(.springBack(dropped, tryAgain: false))
            return
        }
        let wanted = current.matches[charId] ?? []
        let done = links[charId] ?? []
        if wanted.contains(pieceId), !done.contains(pieceId) {
            answers.append((character.item.piece, .right))
            completeLink(r, character: character, pieceId: pieceId, revealed: false)
        } else {
            answers.append((character.item.piece, .tryAgain))
            // Hints help with the animal the child was matching (in one-at-a-time rounds, the animal that is up):
            // clue beside it, arrow on its piece, whichever card was dragged.
            if let piece = wanted.subtracting(done).sorted().first {
                focus((charId, charId, piece))
            }
            scene.show(.springBack(dropped, tryAgain: true))
            tryAgain(lockFor: motion.springBack)
        }
    }

    private func completeLink(_ r: LinkRound, character: Card, pieceId: String, revealed: Bool) {
        let current = r.parts[part]
        let linkedPieces = links.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        let piecesLeft = max(1, current.pieces.count - linkedPieces.count)
        resolve(Skill(character.item.piece), correct: !revealed, guess: 1 / Double(piecesLeft))

        linkFocus = nil
        let now = (links[character.id] ?? []).union([pieceId])
        links[character.id] = now
        scene.show(.linked(character: character.id, piece: pieceId, characterDone: now == current.matches[character.id]))
        if revealed {
            say(VoiceKeys.revealPiece(character.item.piece))
        } else {
            say(cheers.next(from: VoiceKeys.cheers), VoiceKeys.linked(character.item.piece))
        }
        let partDone = current.matches.allSatisfy { links[$0.key] == $0.value }
        if !partDone {
            lock(for: motion.snap)
        } else if part + 1 < r.parts.count {
            part += 1
            lock(for: motion.correct + motion.screenFade) { [weak self] in
                guard let self else { return }
                self.scene.show(.showPart(self.part))
            }
        } else {
            isFinished = true
            scene.inputLocked = true
            stop()
        }
    }

    // MARK: Type 4

    /// First figure still waiting (display order, other-colour figures skipped) and its free slot.
    private func nextShelfFigure(_ r: ShelfRound) -> (Card, String)? {
        for fig in r.figures where !r.distractorIds.contains(fig.id) && !placedFigures.contains(fig.id) {
            if let slot = r.slots.first(where: { $0.piece == fig.item.piece && filled[$0.id] == nil }) { return (fig, slot.id) }
        }
        return nil
    }

    private func shelf(_ r: ShelfRound, _ event: InputEvent) {
        guard case .drop(let figId, let target) = event,
              let figure = r.figures.first(where: { $0.id == figId }) else { return }
        guard let slotId = target, let slot = r.slots.first(where: { $0.id == slotId }) else {
            scene.show(.springBack(figId, tryAgain: false))
            return
        }
        // Other-colour figures never go on the shelf.
        if r.distractorIds.contains(figId) || slot.piece != figure.item.piece {
            answers.append((figure.item.piece, .tryAgain))
            scene.show(.springBack(figId, tryAgain: true))
            tryAgain(lockFor: motion.springBack)
            return
        }
        // Right piece: settle in this slot, or the next free slot of the same piece.
        guard let free = r.slots.first(where: { $0.id == slotId && filled[$0.id] == nil })
                ?? r.slots.first(where: { $0.piece == figure.item.piece && filled[$0.id] == nil }) else {
            scene.show(.springBack(figId, tryAgain: false))
            return
        }
        answers.append((figure.item.piece, .right))
        placeOnShelf(r, figure: figure, slotId: free.id, revealed: false)
    }

    private func placeOnShelf(_ r: ShelfRound, figure: Card, slotId: String, revealed: Bool) {
        let shapesLeft = Set(r.slots.filter { filled[$0.id] == nil }.map(\.piece)).count
        resolve(Skill(figure.item.piece), correct: !revealed, guess: 1 / Double(max(1, shapesLeft)))
        filled[slotId] = figure.item
        placedFigures.insert(figure.id)
        scene.show(.placed(figure: figure.id, slot: slotId))

        let groupFull = r.slots.filter { $0.piece == figure.item.piece }.allSatisfy { filled[$0.id] != nil }
        if filled.count == r.slots.count {
            // Team make-up: once per finished shelf; known if no figure needed hint 3.
            report(TargetResult(skill: .teamMakeup, correct: !anyRevealed, hint: anyRevealed ? .reveal : .none,
                                guess: 1 / Double(r.slots.count), responseMs: nil))
            finish(r.doneKey, cheer: VoiceKeys.finishes)
        } else {
            if revealed {
                say(VoiceKeys.revealPiece(figure.item.piece))
            } else if groupFull, let key = r.countKeys[figure.item.piece] {
                say(cheers.next(from: VoiceKeys.cheers), key)
            }
            lock(for: motion.snap)
        }
    }

    // MARK: Type 5

    private func nextTeamsFigure(_ r: TeamsRound) -> Card? {
        r.batches[batch].first { !placedFigures.contains($0.id) }
    }

    private func teams(_ r: TeamsRound, _ event: InputEvent) {
        guard case .drop(let figId, let target) = event,
              let figure = r.batches[batch].first(where: { $0.id == figId }) else { return }
        guard let house = target else {
            scene.show(.springBack(figId, tryAgain: false))
            return
        }
        let team: ItemColour = house == TeamsScene.whiteHouse ? .white : .black
        guard figure.item.colour == team,
              r.slots.contains(where: { $0.team == team && $0.piece == figure.item.piece && filled[$0.id] == nil }) else {
            answers.append((figure.item.piece, .tryAgain))
            scene.show(.springBack(figId, tryAgain: true))
            tryAgain(lockFor: motion.springBack)
            return
        }
        answers.append((figure.item.piece, .right))
        placeInHouse(r, figure: figure, revealed: false)
    }

    private func placeInHouse(_ r: TeamsRound, figure: Card, revealed: Bool) {
        let team = figure.item.colour
        guard let slot = r.slots.first(where: { $0.team == team && $0.piece == figure.item.piece && filled[$0.id] == nil }) else { return }
        resolve(.colour, correct: !revealed, guess: library.config.bkt.type5Guess)
        filled[slot.id] = figure.item
        placedFigures.insert(figure.id)
        scene.show(.placed(figure: figure.id, slot: slot.id))
        if revealed {
            say(VoiceKeys.teamsReveal(team))
        } else {
            say(cheers.next(from: VoiceKeys.cheers), team == .white ? r.whiteKey : r.blackKey)
        }

        let batchDone = r.batches[batch].allSatisfy { placedFigures.contains($0.id) }
        if batchDone && batch + 1 == r.batches.count {
            finish(r.doneKey, cheer: VoiceKeys.finishes)
        } else if batchDone {
            batch += 1
            lock(for: motion.snap + motion.screenFade) { [weak self] in
                guard let self else { return }
                self.scene.show(.showPart(self.batch))
            }
        } else {
            lock(for: motion.snap)
        }
    }
}
