//
//  CardNode.swift
//  Rounded card (radius 28) holding one item's art. States from DESIGN_SYSTEM "Card states":
//  idle · pressed (0.97) · try again (sunk, 60% alpha, lilac dashed) · correct (moss ring) · dimmed (40%).
//  Calm / Reduce Motion: no bounce, no lift scale, fades only.
//  `plain`: figures the child can't touch (shown figure, kings, pre-placed figures) are drawn as art
//  on a soft ground shadow, no card, so only tappable / draggable things look like buttons.
//

import SpriteKit
import SwiftUI
import RokkoContent

final class CardNode: SKNode {
    let cardId: String
    let item: Item
    let size: CGSize
    /// Where the card lives; drags spring back here.
    var home: CGPoint = .zero

    private let base: SKShapeNode
    private let art: SKNode
    private var ring: SKShapeNode?
    private var dashed: SKShapeNode?
    private var glow: SKShapeNode?
    private(set) var isSunk = false

    init(id: String, item: Item, size: CGSize, cornerRadius: CGFloat = 28, padding: CGFloat = 14, plain: Bool = false) {
        cardId = id
        self.item = item
        self.size = size
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        base = SKShapeNode(rect: rect, cornerRadius: min(cornerRadius, size.width / 4))
        base.fillColor = RokkoColor.ui(RokkoColor.card)
        base.strokeColor = RokkoColor.ui(RokkoColor.cardEdge)
        base.lineWidth = 3
        art = ItemArt.node(for: item, fitting: CGSize(width: size.width - padding * 2, height: size.height - padding * 2))
        super.init()
        name = id
        if plain {
            // Ground shadow under the figure's feet instead of a card.
            let w = size.width * 0.7
            let ground = SKShapeNode(ellipseOf: CGSize(width: w, height: w * 0.16))
            ground.fillColor = RokkoColor.ui(RokkoColor.ink).withAlphaComponent(0.10)
            ground.strokeColor = .clear
            // Sits under the art's own bottom edge (the art is fitted, so it may not reach the padding).
            ground.position = CGPoint(x: 0, y: art.calculateAccumulatedFrame().minY + w * 0.03)
            ground.zPosition = -1
            addChild(ground)
            base.fillColor = .clear
            base.strokeColor = .clear
            base.lineWidth = 0
        } else {
            let shadow = SKShapeNode(rect: rect.offsetBy(dx: 0, dy: -5), cornerRadius: min(cornerRadius, size.width / 4))
            shadow.fillColor = RokkoColor.ui(RokkoColor.ink).withAlphaComponent(0.10)
            shadow.strokeColor = .clear
            shadow.zPosition = -1
            addChild(shadow)
        }
        addChild(base)
        art.zPosition = 1
        addChild(art)
        isAccessibilityElement = true
        accessibilityLabel = item.form == .character ? item.piece.animal : item.piece.displayName
        accessibilityTraits = plain ? .image : .button
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    /// `margin`: extra touch area around the card (EngineConfig › layout.touchSlop).
    func contains(scenePoint p: CGPoint, margin: CGFloat = 0) -> Bool {
        guard let parent else { return false }
        let local = convert(p, from: parent.scene ?? parent)
        return abs(local.x) <= size.width / 2 + margin && abs(local.y) <= size.height / 2 + margin
    }

    // MARK: States

    func press(_ m: SceneMotion) {
        guard !m.fadesOnly else { return }
        run(.scale(to: 0.97, duration: m.press), withKey: "press")
    }

    func release(_ m: SceneMotion) {
        run(.scale(to: 1, duration: m.press), withKey: "press")
    }

    /// Moss ring + 8 pt bounce (fade only in Calm / Reduce Motion).
    func showCorrect(_ m: SceneMotion) {
        let ring = ringNode(color: RokkoColor.ui(RokkoColor.moss), width: 6, dashed: false)
        ring.alpha = 0
        addChild(ring)
        self.ring = ring
        ring.run(.fadeIn(withDuration: m.correct))
        guard !m.fadesOnly else { return }
        let up = SKAction.moveBy(x: 0, y: m.bounce, duration: m.correct / 2)
        up.timingMode = .easeOut
        let down = up.reversed()
        down.timingMode = .easeIn
        run(.sequence([up, down]))
    }

    /// Type 3 match: instead of the thick moss ring, the card's paper takes a soft leaf tint with a thin
    /// moss edge, and its dot (if any) fills moss where the vine attaches. Fades in after `delay`.
    func showMatched(_ m: SceneMotion, after delay: TimeInterval = 0) {
        guard childNode(withName: "matched") == nil else { return }
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        let tint = SKShapeNode(rect: rect, cornerRadius: min(28, size.width / 4))
        tint.name = "matched"
        tint.fillColor = RokkoColor.ui(RokkoColor.mossWash)
        tint.strokeColor = RokkoColor.ui(RokkoColor.moss)
        tint.lineWidth = 3
        tint.zPosition = 0.5                                  // over the card, under the art
        tint.alpha = 0
        addChild(tint)
        tint.run(.sequence([.wait(forDuration: delay), .fadeIn(withDuration: m.correct)]))
        if let dot = childNode(withName: "dot") as? SKShapeNode {
            dot.run(.sequence([.wait(forDuration: delay), .run {
                dot.fillColor = RokkoColor.ui(RokkoColor.moss)
                dot.strokeColor = RokkoColor.ui(RokkoColor.moss)
            }]))
        }
    }

    /// Sinks 16 pt, 60% alpha, lilac dashed outline. Never red, never an X.
    func showTryAgain(_ m: SceneMotion) {
        guard !isSunk else { return }
        isSunk = true
        let outline = ringNode(color: RokkoColor.ui(RokkoColor.lilac), width: 3, dashed: true)
        outline.alpha = 0
        addChild(outline)
        dashed = outline
        let duration = m.tryAgain
        outline.run(.fadeIn(withDuration: duration))
        var actions: [SKAction] = [.fadeAlpha(to: 0.6, duration: duration)]
        if !m.fadesOnly {
            let sink = SKAction.moveBy(x: 0, y: -m.tryAgainSink, duration: duration)
            sink.timingMode = .easeOut
            actions.append(sink)
        }
        run(.group(actions))
    }

    /// A gentle lilac flash (wrong drop target) without sinking the card.
    func flashTryAgain(_ m: SceneMotion) {
        let outline = ringNode(color: RokkoColor.ui(RokkoColor.lilac), width: 3, dashed: true)
        outline.alpha = 0
        addChild(outline)
        outline.run(.sequence([.fadeIn(withDuration: m.tryAgain / 2), .wait(forDuration: m.tryAgain),
                               .fadeOut(withDuration: m.tryAgain), .removeFromParent()]))
    }

    /// Faint glow (honey 30%, DESIGN_SYSTEM card states): a picked-up figure, or the target under a
    /// dragged one. Grows slightly as a target (none in Calm / Reduce Motion). Says nothing about right or wrong.
    func setGlow(_ on: Bool, _ m: SceneMotion, grows: Bool = false) {
        if on {
            if glow == nil {
                let g = ringNode(color: RokkoColor.ui(RokkoColor.honey).withAlphaComponent(0.3), width: 8, dashed: false)
                g.alpha = 0
                addChild(g)
                glow = g
            }
            glow?.run(.fadeIn(withDuration: m.press), withKey: "glow")
        } else {
            glow?.run(.fadeOut(withDuration: m.press), withKey: "glow")
        }
        guard grows, !m.fadesOnly else { return }
        run(.scale(to: on ? m.hoverScale : 1, duration: m.press), withKey: "hover")
    }

    func dim(_ m: SceneMotion) {
        run(.fadeAlpha(to: 0.4, duration: m.tryAgain))
    }

    /// Drag lift: 1.08 scale (none in Calm / Reduce Motion).
    func lift(_ m: SceneMotion) {
        zPosition = 50
        guard !m.fadesOnly else { return }
        run(.scale(to: m.dragLift, duration: m.press), withKey: "press")
    }

    func springBack(_ m: SceneMotion, completion: (() -> Void)? = nil) {
        let move = SKAction.move(to: home, duration: m.springBack)
        move.timingMode = .easeOut
        run(.group([move, .scale(to: 1, duration: m.springBack)])) { [weak self] in
            self?.zPosition = 0
            completion?()
        }
    }

    func snap(to point: CGPoint, scale: CGFloat = 1, _ m: SceneMotion, completion: (() -> Void)? = nil) {
        home = point
        let move = SKAction.move(to: point, duration: m.snap)
        move.timingMode = .easeOut
        run(.group([move, .scale(to: scale, duration: m.snap)])) { [weak self] in
            self?.zPosition = 0
            completion?()
        }
    }

    private func ringNode(color: UIColor, width: CGFloat, dashed: Bool) -> SKShapeNode {
        let inset: CGFloat = dashed ? -2 : -(width / 2 + 2)
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height).insetBy(dx: inset, dy: inset)
        var path = CGPath(roundedRect: rect, cornerWidth: min(30, size.width / 4), cornerHeight: min(30, size.width / 4), transform: nil)
        if dashed { path = path.copy(dashingWithPhase: 0, lengths: [10, 7]) }
        let node = SKShapeNode(path: path)
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.fillColor = .clear
        node.zPosition = 2
        return node
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Card states", traits: .landscapeLeft) {
    SpriteNodePreview(size: CGSize(width: 1194, height: 420)) { scene, motion, design in
        let size = CGSize(width: 160, height: 192)
        let states: [(String, Item, (CardNode) -> Void)] = [
            ("idle", Item(.white, .piece, .king), { _ in }),
            ("pressed", Item(.white, .piece, .queen), { $0.setScale(0.97) }),
            ("try again", Item(.white, .piece, .rook), { $0.showTryAgain(motion) }),
            ("correct", Item(.white, .character, .king), { $0.showCorrect(motion) }),
            ("dimmed", Item(.white, .piece, .bishop), { $0.dim(motion) }),
            ("plain", Item(.black, .piece, .knight), { _ in }),
        ]
        let gap: CGFloat = 26
        let total = CGFloat(states.count) * size.width + CGFloat(states.count - 1) * gap
        for (i, (name, item, apply)) in states.enumerated() {
            let x = (1194 - total) / 2 + size.width / 2 + CGFloat(i) * (size.width + gap)
            let card = CardNode(id: name, item: item, size: size, plain: name == "plain")
            card.position = design(x, 180)
            scene.addChild(card)
            apply(card)
            scene.addChild(SpriteNodePreview.label(name, at: design(x, 320)))
        }
    }
}
#endif
