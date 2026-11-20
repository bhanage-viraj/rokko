//
//  LessonScene.swift
//  Base for every game scene. Scenes draw and report input (tap, drop); they never decide
//  whether an answer is right. The round's view model replies with `Feedback`.
//  Coordinates: scenes lay out in design points (1194 × 834, top-left origin) via `design(_:_:)`.
//

import SpriteKit
import SwiftUI
import RokkoContent

// MARK: - Contract (docs/ARCHITECTURE.md › Scene ⇄ view model)

enum InputEvent: Equatable {
    case tap(String)
    /// A dragged card was let go. `target` is what it was dropped on (card, slot or house id), if anything.
    case drop(String, target: String?)
    /// A finger came down on a card (press or drag start). Not an answer; restarts the idle hint timer.
    case touchBegan
}

enum Feedback: Equatable {
    /// Types 1 · 2
    case correct(String)
    case tryAgain(String)
    case dimAllExcept(String)
    /// Drags: back to where it came from. `tryAgain` adds the soft lilac flash.
    case springBack(String, tryAgain: Bool)
    /// Type 3: line drawn and kept. `characterDone` = this character has all its links.
    case linked(character: String, piece: String, characterDone: Bool)
    /// Types 4 · 5: figure settles into the slot.
    case placed(figure: String, slot: String)
    /// Type 3 level 4: show the next part. Type 5: show the next batch.
    case showPart(Int)
    /// Hint 1: half-transparent clue still of `item`'s animal, beside the node `near`.
    case clue(item: Item, near: String)
    /// Hint 2: honey arrow bobbing above the node `at` (card, slot or house id).
    case arrow(at: String)
    /// Removes the clue card and arrow.
    case clearHints
}

@MainActor
protocol GameSceneDelegate: AnyObject {
    func scene(_ scene: LessonScene, didReport event: InputEvent)
}

/// Motion numbers in seconds / points, read from EngineConfig.json › motion. Calm and Reduce Motion → fades only.
struct SceneMotion {
    var press: TimeInterval
    var correct: TimeInterval
    var bounce: CGFloat
    var tryAgain: TimeInterval
    var tryAgainSink: CGFloat
    var dragLift: CGFloat
    var snap: TimeInterval
    var springBack: TimeInterval
    var screenFade: TimeInterval
    var snapDistance: CGFloat
    var touchSlop: CGFloat
    var dragStartDistance: CGFloat
    var hoverScale: CGFloat
    var linkDemo: TimeInterval
    var linkDemoRepeats: Int
    var linkDemoDelay: TimeInterval
    var arrowBob: CGFloat
    var arrowBobPeriod: TimeInterval
    var fadesOnly: Bool

    init(_ config: EngineConfig, calm: Bool, reduceMotion: Bool) {
        let m = config.motion
        press = m.pressMs / 1000
        correct = m.correctMs / 1000
        bounce = m.bouncePt
        tryAgain = m.tryAgainMs / 1000
        tryAgainSink = m.tryAgainSinkPt
        dragLift = m.dragLiftScale
        snap = m.snapMs / 1000
        springBack = m.springBackMs / 1000
        screenFade = m.screenFadeMs / 1000
        snapDistance = config.layout.snapDistance
        touchSlop = config.layout.touchSlop
        dragStartDistance = config.layout.dragStartDistance
        hoverScale = m.hoverScale
        linkDemo = m.linkDemoMs / 1000
        linkDemoRepeats = m.linkDemoRepeats
        linkDemoDelay = m.linkDemoDelayMs / 1000
        arrowBob = m.arrowBobPt
        arrowBobPeriod = m.arrowBobMs / 1000
        fadesOnly = calm || reduceMotion
    }
}

// MARK: - Base scene

class LessonScene: SKScene {
    weak var gameDelegate: GameSceneDelegate?
    let motion: SceneMotion
    /// Set by the view model while feedback, hints or clips play.
    var inputLocked = false

    /// Cards the child can tap (Types 1 · 2).
    var tappables: [CardNode] = []
    /// Cards the child can drag (Types 3 · 4 · 5).
    var draggables: [CardNode] = []

    /// Choice card under the finger (Types 1 · 2).
    private var pressed: CardNode?
    /// Draggable under the finger. Becomes a drag once the finger travels `dragStartDistance`.
    private var held: CardNode?
    private var isDragging = false
    private var touchStart: CGPoint = .zero
    private var dragOffset: CGPoint = .zero
    /// Tap-to-place: a draggable picked up with a tap waits, lifted and glowing, for a tap on its target.
    private var picked: CardNode?
    /// A tap that began on empty space / a target while a card was picked.
    private var targetTapStart: CGPoint?
    /// Drop target currently glowing under the dragged card.
    private var hovered: String?

    init(motion: SceneMotion) {
        self.motion = motion
        super.init(size: RokkoLayoutSize.canvas)
        scaleMode = .aspectFit
        backgroundColor = .clear
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// Design point (top-left origin) → scene point (bottom-left origin).
    func design(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: size.height - y) }

    /// Subclasses apply their own feedback here and call `super` for the rest (hints).
    func show(_ feedback: Feedback) {
        switch feedback {
        case .clue(let item, let near): showClue(item, near: near)
        case .arrow(let id): showArrow(at: id)
        case .clearHints: clearHints()
        default: break
        }
    }

    // MARK: Hints

    private var hintNodes: [SKNode] = []
    /// The arrow (Hint 2) is kept apart so it can come and go while the clue card (Hint 1) stays up.
    private var arrowNodes: [SKNode] = []

    /// Scene position and size of a card, slot or (TeamsScene) house, for hints to point at.
    func anchor(for id: String) -> (point: CGPoint, size: CGSize)? {
        guard let node = childNode(withName: "//\(id)"), let parent = node.parent else { return nil }
        let point = parent === self ? node.position : parent.convert(node.position, to: self)
        if let card = node as? CardNode { return (point, CGSize(width: card.size.width * card.xScale, height: card.size.height * card.yScale)) }
        if let slot = node as? SlotNode { return (point, slot.size) }
        return (point, node.calculateAccumulatedFrame().size)
    }

    private func clearHints() {
        for node in hintNodes + arrowNodes { node.run(.sequence([.fadeOut(withDuration: motion.press), .removeFromParent()])) }
        hintNodes = []
        arrowNodes = []
    }

    /// Hint 1 clue card: the animal's front half (its face) and the piece's face half, meeting in the middle,
    /// so the child sees the two belong together. Sits in a free spot at the edge of the stage (a corner, or the middle of a side), never on
    /// top of a card or slot; the spot nearest the figure wins. Half-transparent, honey edge.
    private func showClue(_ item: Item, near id: String) {
        clearHints()
        let box = Self.clueSize
        let colour: ItemColour = item.colour == .shaded ? .white : item.colour
        let clue = SKNode()
        let rect = CGRect(x: -box.width / 2, y: -box.height / 2, width: box.width, height: box.height)
        let card = SKShapeNode(rect: rect, cornerRadius: 24)
        card.fillColor = RokkoColor.ui(RokkoColor.card)
        card.strokeColor = RokkoColor.ui(RokkoColor.honey)
        card.lineWidth = 4
        clue.addChild(card)

        // Two halves meet at the seam (see `ClueHalf`), each as large as its side of the card allows;
        // the pair is centred on the card.
        let inner = CGSize(width: box.width - 24, height: box.height - 24)
        let pair = SKNode()
        let left = ClueHalf.animal(item.piece).node(for: Item(colour, .character, item.piece), half: inner, leftOfSeam: true)
        let right = ClueHalf.piece(item.piece).node(for: Item(colour, .piece, item.piece), half: inner, leftOfSeam: false)
        pair.addChild(left.node)
        pair.addChild(right.node)
        pair.position = CGPoint(x: (left.width - right.width) / 2, y: 0)
        pair.zPosition = 1
        clue.addChild(pair)
        let seam = CGMutablePath()
        seam.move(to: CGPoint(x: 0, y: -inner.height / 2))
        seam.addLine(to: CGPoint(x: 0, y: inner.height / 2))
        let divider = SKShapeNode(path: seam.copy(dashingWithPhase: 0, lengths: [6, 5]))
        divider.strokeColor = RokkoColor.ui(RokkoColor.honey)
        divider.lineWidth = 2
        divider.zPosition = 2
        pair.addChild(divider)

        clue.position = clueSpot(near: anchor(for: id)?.point)
        clue.zPosition = 80
        clue.alpha = 0
        addChild(clue)
        hintNodes.append(clue)
        clue.run(.fadeAlpha(to: 0.5, duration: motion.correct))
    }

    static let clueSize = CGSize(width: 180, height: 170)

    /// Things the clue must not cover: every card and slot (subclasses add e.g. the houses).
    func hintObstacles() -> [CGRect] {
        var rects: [CGRect] = []
        enumerateChildNodes(withName: "//*") { node, _ in
            guard node is CardNode || node is SlotNode, let parent = node.parent else { return }
            let frame = node.calculateAccumulatedFrame()
            rects.append(parent === self ? frame : CGRect(origin: parent.convert(frame.origin, to: self), size: frame.size))
        }
        return rects
    }

    /// Corners and side middles of the stage (between the top bar and the bottom band). First choice: a spot
    /// that covers nothing, nearest the figure; otherwise the spot that covers least.
    private func clueSpot(near point: CGPoint?) -> CGPoint {
        let box = Self.clueSize
        let margin: CGFloat = 24
        let left = margin + box.width / 2, right = size.width - margin - box.width / 2
        let top = Self.stageTop + box.height / 2 + 8, bottom = Self.stageBottom - box.height / 2 - 8
        let middle = (Self.stageTop + Self.stageBottom) / 2
        let spots = [(left, top), (right, top), (left, bottom), (right, bottom), (left, middle), (right, middle)]
            .map { design($0.0, $0.1) }
        let obstacles = hintObstacles()
        func covered(_ p: CGPoint) -> CGFloat {
            let r = CGRect(x: p.x - box.width / 2, y: p.y - box.height / 2, width: box.width, height: box.height)
            return obstacles.reduce(0) { sum, o in
                let i = r.intersection(o)
                return sum + (i.isNull ? 0 : i.width * i.height)
            }
        }
        let target = point ?? design(size.width / 2, middle)
        return spots.min { a, b in
            let ca = covered(a), cb = covered(b)
            if ca != cb { return ca < cb }
            return hypot(a.x - target.x, a.y - target.y) < hypot(b.x - target.x, b.y - target.y)
        } ?? spots[0]
    }

    /// Stage between the top bar and the bottom band, in design points (LessonFrame: band starts at 682).
    static let stageTop: CGFloat = 112
    static let stageBottom: CGFloat = 682

    /// HintArrowNode: honey arrow pointing down at the anchor, 6 pt bob (none in Calm / Reduce Motion).
    private func showArrow(at id: String) {
        guard let (point, size) = anchor(for: id) else { return }
        for node in arrowNodes { node.removeFromParent() }   // the clue card stays up
        arrowNodes = []
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: -26, y: 30))
        path.addLine(to: CGPoint(x: -10, y: 30))
        path.addLine(to: CGPoint(x: -10, y: 62))
        path.addLine(to: CGPoint(x: 10, y: 62))
        path.addLine(to: CGPoint(x: 10, y: 30))
        path.addLine(to: CGPoint(x: 26, y: 30))
        path.closeSubpath()
        let arrow = SKShapeNode(path: path)
        arrow.fillColor = RokkoColor.ui(RokkoColor.honey)
        arrow.strokeColor = RokkoColor.ui(RokkoColor.card)
        arrow.lineWidth = 3
        arrow.lineJoin = .round
        arrow.position = CGPoint(x: point.x, y: point.y + size.height / 2 + 10)
        arrow.zPosition = 90
        arrow.alpha = 0
        addChild(arrow)
        arrowNodes.append(arrow)
        arrow.run(.fadeIn(withDuration: motion.correct))
        guard !motion.fadesOnly else { return }
        let up = SKAction.moveBy(x: 0, y: motion.arrowBob, duration: motion.arrowBobPeriod / 2)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        down.timingMode = .easeInEaseOut
        arrow.run(.repeatForever(.sequence([up, down])))
    }

    /// Subclasses: what is under a dragged card when it is let go.
    func dropTarget(for card: CardNode, at point: CGPoint) -> String? { nil }

    func card(_ id: String) -> CardNode? { childNode(withName: "//\(id)") as? CardNode }

    /// Lays `count` items of `width` in a centred row; returns their x centres.
    func rowCentres(count: Int, width: CGFloat, gap: CGFloat, centreX: CGFloat = RokkoLayoutSize.canvas.width / 2) -> [CGFloat] {
        let total = CGFloat(count) * width + CGFloat(max(0, count - 1)) * gap
        let start = centreX - total / 2 + width / 2
        return (0..<count).map { start + CGFloat($0) * (width + gap) }
    }

    // MARK: Hover (drop target under a dragged card)

    /// Glow (and grow) the card, slot or house `id`. Subclasses with other targets override and call super.
    func setHighlight(_ on: Bool, target id: String) {
        if let card = card(id) { card.setGlow(on, motion, grows: true) }
        else if let slot = childNode(withName: "//\(id)") as? SlotNode { slot.setHover(on, motion) }
    }

    private func hover(_ id: String?) {
        guard id != hovered else { return }
        if let old = hovered { setHighlight(false, target: old) }
        hovered = id
        if let id { setHighlight(true, target: id) }
    }

    /// Subclasses: the dragged card moved / was let go (e.g. LinkScene's live line).
    func dragMoved(_ card: CardNode, finger: CGPoint) {}
    func dragEnded(_ card: CardNode) {}

    /// false: the card stays where it is while dragged (it glows; the scene draws a line to the finger instead).
    var dragsMoveCard: Bool { true }

    // MARK: Touch
    //
    // Drag games take a drag OR two taps (tap the figure, tap where it goes): small fingers often
    // lift mid-drag, and tapping is easier than dragging for many children. Both report the same `.drop`.
    // Every card has `touchSlop` extra touch area; the nearest card wins when areas overlap.

    private func nearest(_ cards: [CardNode], to p: CGPoint) -> CardNode? {
        cards.filter { $0.contains(scenePoint: p, margin: motion.touchSlop) }
            .min { hypot($0.position.x - p.x, $0.position.y - p.y) < hypot($1.position.x - p.x, $1.position.y - p.y) }
    }

    private func isLive(_ card: CardNode) -> Bool { draggables.contains { $0 === card } && card.parent != nil }

    /// Drop target for a card: under the card first, then under the finger.
    private func target(for card: CardNode, finger p: CGPoint) -> String? {
        dragsMoveCard ? dropTarget(for: card, at: card.position) ?? dropTarget(for: card, at: p)
                      : dropTarget(for: card, at: p)
    }

    private func putDown(_ card: CardNode) {
        card.setGlow(false, motion)
        card.springBack(motion)
    }

    /// Subclasses: a finger came down (before anything else happens), e.g. to stop a demo.
    func touchWillBegin() {}

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchWillBegin()
        guard !inputLocked, held == nil, pressed == nil, targetTapStart == nil, let touch = touches.first else { return }
        let p = touch.location(in: self)
        if let picked, !isLive(picked) { self.picked = nil }
        if let card = nearest(draggables.filter(isLive), to: p) {
            gameDelegate?.scene(self, didReport: .touchBegan)
            if let other = picked, other !== card { picked = nil; putDown(other) }
            held = card
            isDragging = false
            touchStart = p
            dragOffset = CGPoint(x: card.position.x - p.x, y: card.position.y - p.y)
            card.removeAction(forKey: "press")
            if dragsMoveCard { card.lift(motion) } else { card.setGlow(true, motion) }
        } else if picked != nil {
            gameDelegate?.scene(self, didReport: .touchBegan)
            targetTapStart = p
        } else if let card = nearest(tappables.filter { !$0.isSunk }, to: p) {
            gameDelegate?.scene(self, didReport: .touchBegan)
            pressed = card
            card.press(motion)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let card = held, let touch = touches.first else { return }
        let p = touch.location(in: self)
        if !isDragging {
            guard hypot(p.x - touchStart.x, p.y - touchStart.y) >= motion.dragStartDistance else { return }
            isDragging = true
            if picked === card { picked = nil; if dragsMoveCard { card.setGlow(false, motion) } }
        }
        if dragsMoveCard { card.position = CGPoint(x: p.x + dragOffset.x, y: p.y + dragOffset.y) }
        hover(target(for: card, finger: p))
        dragMoved(card, finger: p)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)
        if let card = held {
            held = nil
            hover(nil)
            if isDragging {
                isDragging = false
                dragEnded(card)
                if !dragsMoveCard { card.setGlow(false, motion) }
                gameDelegate?.scene(self, didReport: .drop(card.cardId, target: target(for: card, finger: p)))
            } else if picked === card {
                // Second tap on the picked card: put it down.
                picked = nil
                putDown(card)
            } else {
                // Tap: pick it up. It stays lifted and glowing until a target (or it) is tapped.
                picked = card
                card.setGlow(true, motion)
            }
        } else if let start = targetTapStart {
            targetTapStart = nil
            guard let card = picked else { return }
            picked = nil
            card.setGlow(false, motion)
            let moved = hypot(p.x - start.x, p.y - start.y) >= motion.dragStartDistance
            if !moved, isLive(card), let id = dropTarget(for: card, at: p) {
                gameDelegate?.scene(self, didReport: .drop(card.cardId, target: id))
            } else {
                card.springBack(motion)
            }
        } else if let card = pressed {
            pressed = nil
            card.release(motion)
            if card.contains(scenePoint: p, margin: motion.touchSlop) {
                gameDelegate?.scene(self, didReport: .tap(card.cardId))
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        hover(nil)
        if let card = held {
            held = nil
            if isDragging { dragEnded(card) }
            isDragging = false
            if picked === card { picked = nil }
            putDown(card)
        }
        if let card = pressed { pressed = nil; card.release(motion) }
        targetTapStart = nil
    }
}

enum RokkoLayoutSize {
    /// Same canvas as RokkoLayout.canvas (DESIGN_SYSTEM: 1194 × 834).
    static let canvas = CGSize(width: 1194, height: 834)
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)
// Shared drag/tap/hint code. Wrong-answer the round in Live mode to see the clue and arrow hints.

#if DEBUG
#Preview("Hints · Type 1 (tap a wrong card)", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-01-01", level: 1)
}
#Preview("Hints · Type 4 (drop in a wrong slot)", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-04-03", level: 1)
}
#endif
