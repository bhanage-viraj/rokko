//
//  ShelfScene.swift
//  Type 4: one team's shelf. One of each (one tier: K Q R B N P), or the whole team of 16 on two tiers
//  (K Q R R B B N N above, 8 Pawns below). Figures wait below (one or two rows); the child drags each
//  into a matching slot.
//  Level 6 adds other-colour figures that spring back and stay off the shelf.
//

import SpriteKit
import SwiftUI
import RokkoContent
import RokkoEngine

final class ShelfScene: LessonScene {
    private let round: ShelfRound
    private var slotNodes: [String: SlotNode] = [:]

    /// One tier (one of each): big slots. Two tiers (whole team of 16): smaller slots, 8 to a tier.
    private var tiers: Int { (round.slots.map(\.tier).max() ?? 0) + 1 }
    private var slotSize: CGSize { tiers == 1 ? CGSize(width: 120, height: 132) : CGSize(width: 96, height: 108) }
    private var slotGap: CGFloat { tiers == 1 ? 20 : 12 }
    /// Centre y of each tier (design points). Two tiers end at 350, clear of the figures below.
    private var tierYs: [CGFloat] { tiers == 1 ? [250] : [176, 296] }

    init(round: ShelfRound, motion: SceneMotion) {
        self.round = round
        super.init(motion: motion)
        buildShelf()
        buildFigures()
    }

    private func buildShelf() {
        for (tier, tierY) in tierYs.enumerated() {
            let tierSlots = round.slots.filter { $0.tier == tier }
            let xs = rowCentres(count: tierSlots.count, width: slotSize.width, gap: slotGap)

            // Plank under each tier (prop_shelf.png replaces this when it arrives).
            let width = (xs.last ?? 0) - (xs.first ?? 0) + slotSize.width + 36
            let plank = SKShapeNode(rect: CGRect(x: -width / 2, y: -6, width: width, height: 12), cornerRadius: 6)
            plank.fillColor = RokkoColor.ui(RokkoColor.cardEdge)
            plank.strokeColor = .clear
            plank.position = design(size.width / 2, tierY + slotSize.height / 2 + 8)
            plank.zPosition = -2
            addChild(plank)

            for slot in tierSlots {
                let node = SlotNode(id: slot.id, silhouette: Item(round.team, round.form, slot.piece), size: slotSize)
                node.position = design(xs[slot.index], tierY)
                node.zPosition = -1
                addChild(node)
                slotNodes[slot.id] = node
                if let item = round.prefilled[slot.id] {
                    let figure = CardNode(id: "pre_\(slot.id)", item: item, size: slotSize, cornerRadius: 16, padding: 8, plain: true)
                    figure.position = node.position
                    figure.isAccessibilityElement = false
                    addChild(figure)
                    node.markFilled()
                }
            }
        }
    }

    private func buildFigures() {
        let count = round.figures.count
        guard count > 0 else { return }
        // At most 2 rows, kept even: up to 6 a row on a one-tier shelf, 8 on the full-team shelf;
        // more than that (level 6, 16 + 6) shrinks the cards so a row still fits the stage.
        let gap: CGFloat = tiers == 1 ? 24 : 18
        let rowCount = count > (tiers == 1 ? 6 : 8) ? 2 : 1
        let perRow = (count + rowCount - 1) / rowCount
        let fitWidth = (RokkoLayoutSize.canvas.width - 48 - gap * CGFloat(perRow - 1)) / CGFloat(perRow)
        let width = min(110, fitWidth)
        let size = CGSize(width: width, height: width * 124 / 110)
        let rows = stride(from: 0, to: count, by: perRow).map { Array(round.figures[$0..<min($0 + perRow, count)]) }
        let ys: [CGFloat] = tiers == 1
            ? (rows.count == 1 ? [540] : [468, 606])   // second row ends at 668, clear of the bottom band (682)
            : (rows.count == 1 ? [516] : [450, 600])   // below the two tiers (end 350); last row ends at 662
        for (row, y) in zip(rows, ys) {
            for (card, x) in zip(row, rowCentres(count: row.count, width: size.width, gap: gap)) {
                let node = CardNode(id: card.id, item: card.item, size: size, cornerRadius: 16, padding: 8)
                node.position = design(x, y)
                node.home = node.position
                addChild(node)
                draggables.append(node)
            }
        }
    }

    override func dropTarget(for card: CardNode, at point: CGPoint) -> String? {
        slotNodes.values
            .filter { !$0.isFilled && $0.contains(scenePoint: point, margin: motion.snapDistance / 2) }
            .min { hypot($0.position.x - point.x, $0.position.y - point.y) < hypot($1.position.x - point.x, $1.position.y - point.y) }?
            .slotId
    }


    override func show(_ feedback: Feedback) {
        switch feedback {
        case .springBack(let id, let tryAgain):
            guard let node = card(id) else { return }
            node.springBack(motion)
            if tryAgain { node.flashTryAgain(motion) }
        case .placed(let figureId, let slotId):
            guard let node = card(figureId), let slot = slotNodes[slotId] else { return }
            slot.markFilled()
            draggables.removeAll { $0 === node }
            node.snap(to: slot.position, scale: slotSize.width / node.size.width, motion)
        default:
            super.show(feedback)
        }
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Type 4 · L1 · shelf", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-04-03", level: 1)
}
#Preview("Type 4 · L6 · shelf + other colour", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-04-03", level: 6)
}
#Preview("Type 4 · L1 · black pieces, whole team", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-04-04", level: 1)
}
#Preview("Type 4 · L3 · black pieces, whole team", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-04-04", level: 3)
}
#Preview("Type 4 · L1 · Calm", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-04-03", level: 1, calm: true)
}
#endif
