//
//  SlotNode.swift
//  Silhouette slot for the team shelf (Type 4) and the houses (Type 5): the item's own art,
//  tinted flat and faint, on a soft dashed well. Drawn in code (docs/ASSETS.md: slot silhouettes = code).
//

import SpriteKit
import SwiftUI
import RokkoContent

final class SlotNode: SKNode {
    let slotId: String
    let piece: Piece
    let size: CGSize
    private(set) var isFilled = false
    private let well: SKShapeNode

    init(id: String, silhouette item: Item, size: CGSize) {
        slotId = id
        piece = item.piece
        self.size = size
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        well = SKShapeNode(path: CGPath(roundedRect: rect, cornerWidth: 16, cornerHeight: 16, transform: nil)
            .copy(dashingWithPhase: 0, lengths: [6, 5]))
        super.init()
        name = id
        well.strokeColor = RokkoColor.ui(RokkoColor.cardEdge)
        well.lineWidth = 2
        well.fillColor = RokkoColor.ui(RokkoColor.card).withAlphaComponent(0.55)
        addChild(well)

        let art = ItemArt.node(for: item, fitting: CGSize(width: size.width - 14, height: size.height - 14))
        if let sprite = art as? SKSpriteNode {
            sprite.color = RokkoColor.ui(RokkoColor.inkSoft)
            sprite.colorBlendFactor = 1
            sprite.alpha = 0.22
        } else {
            art.alpha = 0.3
        }
        addChild(art)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    func markFilled() { isFilled = true; setHover(false, nil) }

    /// A figure is being dragged over this slot: honey edge (faint glow) and a slight grow.
    func setHover(_ on: Bool, _ m: SceneMotion?) {
        well.strokeColor = on ? RokkoColor.ui(RokkoColor.honey) : RokkoColor.ui(RokkoColor.cardEdge)
        well.lineWidth = on ? 4 : 2
        well.fillColor = RokkoColor.ui(RokkoColor.card).withAlphaComponent(on ? 0.9 : 0.55)
        guard let m, !m.fadesOnly else { setScale(1); return }
        run(.scale(to: on ? m.hoverScale : 1, duration: m.press), withKey: "hover")
    }

    func contains(scenePoint p: CGPoint, margin: CGFloat) -> Bool {
        guard let scene else { return false }
        let local = convert(p, from: scene)
        return abs(local.x) <= size.width / 2 + margin && abs(local.y) <= size.height / 2 + margin
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Slots · white and black", traits: .landscapeLeft) {
    SpriteNodePreview(size: CGSize(width: 1194, height: 420)) { scene, _, design in
        let size = CGSize(width: 120, height: 140)
        let gap: CGFloat = 24
        let total = 6 * size.width + 5 * gap
        for (row, colour) in [ItemColour.white, .black].enumerated() {
            for (i, piece) in Piece.allCases.enumerated() {
                let x = (1194 - total) / 2 + size.width / 2 + CGFloat(i) * (size.width + gap)
                let slot = SlotNode(id: "\(colour)-\(piece)", silhouette: Item(colour, .piece, piece), size: size)
                slot.position = design(x, 110 + CGFloat(row) * 200)
                scene.addChild(slot)
            }
        }
    }
}
#endif
