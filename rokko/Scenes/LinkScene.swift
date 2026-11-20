//
//  LinkScene.swift
//  Type 3: drag from an animal to its piece, or from a piece to its animal (the card stays put; a dashed
//  line follows the finger); a gently curved moss line joins them and stays.
//  Levels 1–4: two columns, animals left and pieces right, curved lines dot to dot (level 4 in two parts of 5).
//  Level 5: four bands (white pieces · white characters · black characters · black pieces).
//  Level 6: shaded characters in the middle; white pieces top, black pieces bottom.
//  Levels 5–6 layout is a placeholder until the sketch for DECISIONS O11.
//

import SpriteKit
import CoreImage
import SwiftUI
import RokkoContent
import RokkoEngine

final class LinkScene: LessonScene {
    private let round: LinkRound
    private let level: Int
    private let dragCard: CGSize
    private var partNode = SKNode()
    private var pieceNodes: [CardNode] = []
    private var characterNodes: [CardNode] = []
    /// Dashed line from the dragged card's dot to the finger.
    private var liveLine: SKShapeNode?
    /// Faint leaves along the drag line (reused while the finger moves).
    private var liveLeaves: [SKNode] = []
    /// One animal at a time (columns layout): the others wait blurred and can't be touched.
    private let waitingBlur: CGFloat
    private let waitingAlpha: CGFloat
    private var doneCharacters = Set<String>()
    private var blurRadius: [String: CGFloat] = [:]

    init(round: LinkRound, level: Int, layout: EngineConfig.Layout, motion: SceneMotion) {
        self.round = round
        self.level = level
        waitingBlur = layout.linkWaitingBlur
        waitingAlpha = layout.linkWaitingAlpha
        dragCard = CGSize(width: layout.dragCardMin[0], height: layout.dragCardMin[1])
        super.init(motion: motion)
        addChild(partNode)
        build(part: 0, animated: false)
        playDemo()
    }

    private func build(part index: Int, animated: Bool) {
        partNode.removeFromParent()
        partNode = SKNode()
        addChild(partNode)
        draggables = []
        pieceNodes = []
        characterNodes = []
        doneCharacters = []
        blurRadius = [:]
        let part = round.parts[index]

        switch round.layout {
        case .rows:
            // "Match the column": animals in a left column, pieces in a right column, lines go across.
            let n = max(part.characters.count, part.pieces.count)
            let gap: CGFloat = 12
            let height = min(dragCard.height, (Self.stageHeight - gap * CGFloat(n - 1)) / CGFloat(n))
            let size = CGSize(width: Self.columnCardWidth, height: height)
            placeColumn(part.characters, x: size.width / 2 + Self.columnOffset(-1), size: size, gap: gap, isCharacter: true)
            placeColumn(part.pieces, x: size.width / 2 + Self.columnOffset(1), size: size, gap: gap, isCharacter: false)

        case .colourBands:
            // Smaller than dragCardMin so four bands fit the stage (y 112–680).
            let size = CGSize(width: 100, height: 118)
            let ys: [CGFloat] = [190, 323, 456, 589]
            place(part.pieces.filter { $0.item.colour == .white }, y: ys[0], size: size, gap: 20, isCharacter: false)
            place(part.characters.filter { $0.item.colour == .white }, y: ys[1], size: size, gap: 20, isCharacter: true)
            place(part.characters.filter { $0.item.colour == .black }, y: ys[2], size: size, gap: 20, isCharacter: true)
            place(part.pieces.filter { $0.item.colour == .black }, y: ys[3], size: size, gap: 20, isCharacter: false)

        case .shaded:
            let size = dragCard
            place(part.pieces.filter { $0.item.colour == .white }, y: 190, size: size, gap: 24, isCharacter: false)
            place(part.characters, y: 400, size: size, gap: 24, isCharacter: true)
            place(part.pieces.filter { $0.item.colour == .black }, y: 610, size: size, gap: 24, isCharacter: false)
        }

        if animated {
            partNode.alpha = 0
            partNode.run(.fadeIn(withDuration: motion.screenFade))
        }
    }

    private func place(_ cards: [Card], y: CGFloat, size: CGSize, gap: CGFloat, isCharacter: Bool) {
        let xs = rowCentres(count: cards.count, width: size.width, gap: gap)
        for (card, x) in zip(cards, xs) {
            let node = CardNode(id: card.id, item: card.item, size: size, cornerRadius: 22, padding: 10)
            node.position = design(x, y)
            node.home = node.position
            partNode.addChild(node)
            // Both sides can be dragged: an animal onto its piece, or a piece onto its animal.
            draggables.append(node)
            if isCharacter { characterNodes.append(node) } else { pieceNodes.append(node) }
        }
    }

    /// Columns layout: card width, the stage height the column may fill, and the gap between the columns.
    static let columnCardWidth: CGFloat = 190
    static let stageHeight: CGFloat = 550
    static let columnGap: CGFloat = 330
    /// Left edge of the left column (side -1) or of the right column (side 1), in design points.
    static func columnOffset(_ side: CGFloat) -> CGFloat {
        let total = columnCardWidth * 2 + columnGap
        let left = (RokkoLayoutSize.canvas.width - total) / 2
        return side < 0 ? left : left + columnCardWidth + columnGap
    }

    private func placeColumn(_ cards: [Card], x: CGFloat, size: CGSize, gap: CGFloat, isCharacter: Bool) {
        let total = CGFloat(cards.count) * size.height + CGFloat(max(0, cards.count - 1)) * gap
        let top = 112 + (Self.stageHeight + 20 - total) / 2 + size.height / 2
        for (i, card) in cards.enumerated() {
            let node = CardNode(id: card.id, item: card.item, size: size, cornerRadius: 20, padding: 8)
            node.position = design(x, top + CGFloat(i) * (size.height + gap))
            node.home = node.position
            // Dot on the inner edge: where the line starts and ends.
            let dot = SKShapeNode(circleOfRadius: 8)
            dot.name = "dot"
            dot.fillColor = RokkoColor.ui(RokkoColor.card)
            dot.strokeColor = RokkoColor.ui(RokkoColor.inkSoft)
            dot.lineWidth = 3
            dot.position = CGPoint(x: (isCharacter ? 1 : -1) * size.width / 2, y: 0)
            dot.zPosition = 3
            node.addChild(dot)
            if isCharacter {
                // Each animal sits in its own effect node so it can be blurred while it waits its turn.
                let holder = SKEffectNode()
                holder.filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 0])
                holder.shouldEnableEffects = false
                holder.addChild(node)
                partNode.addChild(holder)
                characterNodes.append(node)
            } else {
                partNode.addChild(node)
                pieceNodes.append(node)
            }
            draggables.append(node)
        }
        if isCharacter { refocus(animated: false) }
    }

    // MARK: One animal at a time

    /// The first animal not yet done is sharp and can be dragged; the others wait blurred, faded and untouchable.
    /// Pieces are always clear. Called at build and after each animal is done.
    private func refocus(animated: Bool) {
        let up = characterNodes.first { !doneCharacters.contains($0.cardId) }
        draggables.removeAll { node in characterNodes.contains { $0 === node } }
        if let up { draggables.append(up) }
        for ch in characterNodes where !doneCharacters.contains(ch.cardId) {
            let waiting = ch !== up
            setWaiting(ch, waiting, animated: animated)
        }
    }

    private func setWaiting(_ card: CardNode, _ waiting: Bool, animated: Bool) {
        guard let holder = card.parent as? SKEffectNode else { return }
        let from = blurRadius[card.cardId] ?? 0, to = waiting ? waitingBlur : 0
        blurRadius[card.cardId] = to
        let alpha = waiting ? waitingAlpha : 1
        guard animated else {
            holder.filter?.setValue(to, forKey: kCIInputRadiusKey)
            holder.shouldEnableEffects = to > 0
            card.alpha = alpha
            return
        }
        holder.shouldEnableEffects = true
        let duration = motion.correct
        holder.run(.customAction(withDuration: duration) { node, elapsed in
            let t = min(1, elapsed / CGFloat(duration))
            (node as? SKEffectNode)?.filter?.setValue(from + (to - from) * t, forKey: kCIInputRadiusKey)
            if t >= 1 { (node as? SKEffectNode)?.shouldEnableEffects = to > 0 }
        })
        card.run(.fadeAlpha(to: alpha, duration: duration))
    }

    private var columns: Bool { round.layout == .rows }

    /// Line between two cards (or a card and the finger when `endSize` is nil).
    /// Columns: a smooth curve, dot to dot across. Bands: from facing top/bottom edges with a gentle bend.
    private func linkPath(from a: CGPoint, size: CGSize, to b: CGPoint, endSize: CGSize?) -> CGPath {
        linkCurve(from: a, size: size, to: b, endSize: endSize).path
    }

    private func linkCurve(from a: CGPoint, size: CGSize, to b: CGPoint, endSize: CGSize?) -> Bezier {
        guard columns else { return Self.curve(from: a, size: size, to: b, endSize: endSize) }
        let side: CGFloat = b.x > a.x ? 1 : -1
        let start = CGPoint(x: a.x + side * size.width / 2, y: a.y)
        let end = endSize.map { CGPoint(x: b.x - side * $0.width / 2, y: b.y) } ?? b
        // Smooth curve: leaves one dot straight out sideways and arrives level at the other.
        let pull = abs(end.x - start.x) * 0.45
        return Bezier(p0: start, p1: CGPoint(x: start.x + side * pull, y: start.y),
                      p2: CGPoint(x: end.x - side * pull, y: end.y), p3: end)
    }
    // MARK: "Show me" demo

    private static let demoKey = "linkDemo"
    private var demoCard: CardNode?

    /// Round start: a faint vine grows from the first animal's dot out toward the pieces column (never all the way
    /// to a piece, so it shows the move, not the answer), fades, and plays again. Any touch stops it; input is never locked.
    private func playDemo() {
        guard columns, motion.linkDemoRepeats > 0, let card = characterNodes.first else { return }
        demoCard = card
        let side: CGFloat = 1
        let from = CGPoint(x: card.home.x + side * card.size.width / 2, y: card.home.y)
        let reach = (Self.columnGap * 0.7)
        let grow = SKAction.customAction(withDuration: motion.linkDemo) { [weak self] _, elapsed in
            guard let self else { return }
            let t = min(1, elapsed / CGFloat(self.motion.linkDemo))
            let eased = t * t * (3 - 2 * t)
            self.dragMoved(card, finger: CGPoint(x: from.x + reach * eased, y: from.y + 18 * sin(eased * .pi)))
        }
        let fadeIn: SKAction = .run { [weak self] in self?.dragMoved(card, finger: CGPoint(x: from.x + reach, y: from.y)) }
        let show = motion.fadesOnly ? fadeIn : grow
        let once = SKAction.sequence([
            .run { [weak self] in self?.dragEnded(card) },
            .run { card.setGlow(true, self.motion) },
            show,
            .wait(forDuration: motion.correct),
            .run { [weak self] in
                guard let self else { return }
                card.setGlow(false, self.motion)
                for node in [self.liveLine as SKNode?].compactMap({ $0 }) + self.liveLeaves {
                    node.run(.fadeOut(withDuration: self.motion.correct))
                }
            },
            .wait(forDuration: motion.correct + motion.press),
        ])
        run(.sequence([.wait(forDuration: motion.linkDemoDelay), .repeat(once, count: motion.linkDemoRepeats),
                       .run { [weak self] in self?.stopDemo() }]), withKey: Self.demoKey)
    }

    private func stopDemo() {
        guard let card = demoCard else { return }
        demoCard = nil
        removeAction(forKey: Self.demoKey)
        card.setGlow(false, motion)
        dragEnded(card)
    }

    override func touchWillBegin() { stopDemo() }

    /// Cards stay put: dragging draws a soft dashed line from the card's dot to the finger.
    override var dragsMoveCard: Bool { false }

    /// While dragging: a faint dashed vine from the card's dot to the finger, leaves along it.
    override func dragMoved(_ card: CardNode, finger: CGPoint) {
        let curve = linkCurve(from: card.home, size: card.size, to: finger, endSize: nil)
        if liveLine == nil {
            let line = SKShapeNode()
            line.strokeColor = RokkoColor.ui(RokkoColor.moss).withAlphaComponent(0.55)
            line.lineWidth = 3
            line.lineCap = .round
            line.zPosition = 10
            partNode.addChild(line)
            liveLine = line
        }
        liveLine?.path = curve.path.copy(dashingWithPhase: 0, lengths: [8, 7])

        let count = max(0, Int(curve.length / Self.leafSpacing) - 1)
        let texture = UIImage(named: "vine_leaf").map { SKTexture(image: $0) }
        while liveLeaves.count < count {
            let leaf = Self.leaf(texture: texture)
            leaf.alpha = 0.45
            leaf.zPosition = 10
            partNode.addChild(leaf)
            liveLeaves.append(leaf)
        }
        for (i, leaf) in liveLeaves.enumerated() {
            leaf.isHidden = i >= count
            guard i < count else { continue }
            let t = CGFloat(i + 1) / CGFloat(count + 1)
            let side: CGFloat = (i + 1) % 2 == 0 ? 1 : -1
            leaf.position = curve.point(t)
            leaf.zRotation = curve.angle(t) + side * .pi / 4
        }
    }

    override func dragEnded(_ card: CardNode) {
        liveLine?.removeFromParent()
        liveLine = nil
        liveLeaves.forEach { $0.removeFromParent() }
        liveLeaves = []
    }

    /// The card on the other side under `point`: pieces for a dragged animal, animals still to link for a dragged piece.
    override func dropTarget(for card: CardNode, at point: CGPoint) -> String? {
        let isPiece = pieceNodes.contains { $0 === card }
        let others = isPiece ? characterNodes.filter { c in draggables.contains { $0 === c } } : pieceNodes
        let margin = motion.snapDistance / 2
        return others
            .filter { abs($0.position.x - point.x) <= $0.size.width / 2 + margin
                   && abs($0.position.y - point.y) <= $0.size.height / 2 + margin }
            .min { hypot($0.position.x - point.x, $0.position.y - point.y) < hypot($1.position.x - point.x, $1.position.y - point.y) }?
            .cardId
    }

    override func show(_ feedback: Feedback) {
        switch feedback {
        case .springBack(let id, let tryAgain):
            guard let node = card(id) else { return }
            node.springBack(motion)
            if tryAgain { node.flashTryAgain(motion) }

        case .linked(let charId, let pieceId, let done):
            guard let ch = card(charId), let pc = card(pieceId) else { return }
            // Whichever one was dragged goes home; the line joins the two cards where they live.
            ch.springBack(motion)
            pc.springBack(motion)
            drawLine(between: ch, and: pc)
            pc.showMatched(motion, after: motion.springBack)
            draggables.removeAll { $0 === pc }
            if done {
                ch.showMatched(motion, after: motion.springBack)
                draggables.removeAll { $0 === ch }
                doneCharacters.insert(ch.cardId)
                // The next animal comes up once the vine has started to grow.
                run(.sequence([.wait(forDuration: motion.springBack + motion.correct),
                               .run { [weak self] in self?.refocus(animated: true) }]))
            }

        case .showPart(let index):
            guard index < round.parts.count else { return }
            partNode.run(.sequence([.fadeOut(withDuration: motion.screenFade), .run { [weak self] in
                self?.build(part: index, animated: true)
            }]))

        default:
            super.show(feedback)
        }
    }

    /// LinkLineNode: a little vine. A thin moss stem along the curve, then leaves along it (alternating sides),
    /// appearing one after another from the animal to the piece. Leaves use `vine_leaf.png` when it is in the
    /// app (docs/ASSETS.md), otherwise a leaf drawn in code. Calm / Reduce Motion: fades only.
    private func drawLine(between a: CardNode, and b: CardNode) {
        let curve = linkCurve(from: a.home, size: a.size, to: b.home, endSize: b.size)
        let vine = SKNode()
        vine.zPosition = -5
        partNode.addChild(vine)

        let stem = SKShapeNode(path: curve.path)
        stem.strokeColor = RokkoColor.ui(RokkoColor.moss)
        stem.lineWidth = 4
        stem.lineCap = .round
        stem.alpha = 0
        vine.addChild(stem)
        let start = motion.springBack                       // once the dragged card is home
        stem.run(.sequence([.wait(forDuration: start), .fadeIn(withDuration: motion.correct)]))

        let count = max(1, Int(curve.length / Self.leafSpacing) - 1)
        let texture = UIImage(named: "vine_leaf").map { SKTexture(image: $0) }
        for i in 1...count {
            let t = CGFloat(i) / CGFloat(count + 1)
            let side: CGFloat = i % 2 == 0 ? 1 : -1
            let leaf = Self.leaf(texture: texture)
            leaf.position = curve.point(t)
            leaf.zRotation = curve.angle(t) + side * .pi / 4
            leaf.alpha = 0
            vine.addChild(leaf)
            let delay = start + motion.correct * 0.5 + Double(i) * motion.press * 0.6
            if motion.fadesOnly {
                leaf.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: motion.correct)]))
            } else {
                leaf.setScale(0.4)
                leaf.run(.sequence([.wait(forDuration: delay),
                                    .group([.fadeIn(withDuration: motion.press), .scale(to: 1, duration: motion.correct)])]))
            }
        }
    }

    /// Gap between leaves along the vine.
    static let leafSpacing: CGFloat = 34

    /// One leaf, base at (0, 0), pointing along +x, 22 pt long.
    private static func leaf(texture: SKTexture?) -> SKNode {
        let length: CGFloat = 22
        if let texture {
            let sprite = SKSpriteNode(texture: texture)
            sprite.anchorPoint = CGPoint(x: 0, y: 0.5)
            sprite.setScale(length / max(texture.size().width, 1))
            return sprite
        }
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addQuadCurve(to: CGPoint(x: length, y: 0), control: CGPoint(x: length * 0.45, y: length * 0.42))
        path.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.45, y: -length * 0.42))
        let leaf = SKShapeNode(path: path)
        leaf.fillColor = RokkoColor.ui(RokkoColor.moss)
        leaf.strokeColor = RokkoColor.ui(RokkoColor.moss).withAlphaComponent(0.6)
        leaf.lineWidth = 1
        let vein = CGMutablePath()
        vein.move(to: CGPoint(x: 2, y: 0))
        vein.addLine(to: CGPoint(x: length * 0.75, y: 0))
        let line = SKShapeNode(path: vein)
        line.strokeColor = RokkoColor.ui(RokkoColor.card).withAlphaComponent(0.55)
        line.lineWidth = 1.2
        leaf.addChild(line)
        return leaf
    }
    /// From the facing edge of the first card to the facing edge of the second (or to `to` itself when
    /// `endSize` is nil: the finger while dragging), with one gentle bend: almost straight, never under a card.
    static func curve(from a: CGPoint, size: CGSize, to b: CGPoint, endSize: CGSize?) -> Bezier {
        let gap: CGFloat = 6
        let bend: CGFloat = 0.08                         // sideways bow, as a share of the line's length
        let down: CGFloat = b.y < a.y ? -1 : 1          // scene y points up
        let start = CGPoint(x: a.x, y: a.y + down * (size.height / 2 + gap))
        let end = endSize.map { CGPoint(x: b.x, y: b.y - down * ($0.height / 2 + gap)) } ?? b
        let dx = end.x - start.x, dy = end.y - start.y
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let control = CGPoint(x: mid.x - dy * bend, y: mid.y + dx * bend)
        // Quadratic as cubic, so both layouts share one curve type.
        return Bezier(p0: start, p1: CGPoint(x: start.x + 2 / 3 * (control.x - start.x), y: start.y + 2 / 3 * (control.y - start.y)),
                      p2: CGPoint(x: end.x + 2 / 3 * (control.x - end.x), y: end.y + 2 / 3 * (control.y - end.y)), p3: end)
    }}

/// Cubic Bézier: the link line's shape, sampled for the vine's leaves.
struct Bezier {
    var p0, p1, p2, p3: CGPoint

    var path: CGPath {
        let p = CGMutablePath()
        p.move(to: p0)
        p.addCurve(to: p3, control1: p1, control2: p2)
        return p
    }

    func point(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
        return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x, y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
    }

    /// Direction of travel at `t`, in radians.
    func angle(_ t: CGFloat) -> CGFloat {
        let u = 1 - t
        let dx = 3 * u * u * (p1.x - p0.x) + 6 * u * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x)
        let dy = 3 * u * u * (p1.y - p0.y) + 6 * u * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y)
        return atan2(dy, dx)
    }

    var length: CGFloat {
        var total: CGFloat = 0, last = p0
        for i in 1...24 { let p = point(CGFloat(i) / 24); total += hypot(p.x - last.x, p.y - last.y); last = p }
        return total
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Type 3 · L1 · two columns", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-03-01", level: 1)
}
#Preview("Type 3 · L4 · two parts", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-03-01", level: 4)
}
#Preview("Type 3 · L5 · four rows", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-03-01", level: 5)
}
#Preview("Type 3 · L6 · shaded middle", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-03-01", level: 6)
}
#Preview("Type 3 · L1 · Calm", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-03-01", level: 1, calm: true)
}
#endif
