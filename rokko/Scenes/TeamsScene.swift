//
//  TeamsScene.swift
//  Type 5: white king top-left, black king top-right, each with a house of one slot
//  per piece (K Q R B N P). Figures arrive from the basket in batches;
//  the child drags each into its team's house, where it settles in a free slot of its piece.
//

import SpriteKit
import SwiftUI
import RokkoContent
import RokkoEngine

final class TeamsScene: LessonScene {
    static let whiteHouse = "house.white"
    static let blackHouse = "house.black"

    private let round: TeamsRound
    private var slotNodes: [String: SlotNode] = [:]
    private var houseRects: [String: CGRect] = [:]
    private var housePanels: [String: SKShapeNode] = [:]
    private var batchNode = SKNode()

    private let slotSize = CGSize(width: 78, height: 92)
    private let slotGap: CGFloat = 10
    private let houseCentreX: [ItemColour: CGFloat] = [.white: 301, .black: 893]
    private let rowY: CGFloat = 350

    init(round: TeamsRound, motion: SceneMotion) {
        self.round = round
        super.init(motion: motion)
        buildHouses()
        buildBasket()
        addChild(batchNode)
        showBatch(0, animated: false)
    }

    private func buildHouses() {
        for team in [ItemColour.white, .black] {
            let cx = houseCentreX[team]!
            let count = round.slots.filter { $0.team == team }.count
            let xs = rowCentres(count: count, width: slotSize.width, gap: slotGap, centreX: cx)

            // House panel (prop_house_* replaces this when it arrives).
            let w = CGFloat(count) * slotSize.width + CGFloat(max(0, count - 1)) * slotGap + 28
            let h = slotSize.height + 28
            let top = rowY - slotSize.height / 2 - 14
            let rect = CGRect(x: cx - w / 2, y: size.height - top - h, width: w, height: h)
            let panel = SKShapeNode(rect: rect, cornerRadius: 24)
            panel.fillColor = RokkoColor.ui(team == .white ? RokkoColor.card : RokkoColor.charcoalTint).withAlphaComponent(team == .white ? 0.85 : 0.22)
            panel.strokeColor = RokkoColor.ui(RokkoColor.cardEdge)
            panel.lineWidth = 3
            panel.zPosition = -3
            addChild(panel)
            let houseId = team == .white ? Self.whiteHouse : Self.blackHouse
            houseRects[houseId] = rect
            housePanels[houseId] = panel

            let king = CardNode(id: "king_\(team.rawValue)", item: team == .white ? round.whiteKing : round.blackKing,
                                size: CGSize(width: 104, height: 120), padding: 10, plain: true)
            king.position = design(cx, 194)
            king.isAccessibilityElement = false
            addChild(king)

            for slot in round.slots where slot.team == team {
                let node = SlotNode(id: slot.id, silhouette: Item(team, round.whiteKing.form, slot.piece), size: slotSize)
                node.position = design(xs[slot.index], rowY)
                node.zPosition = -1
                addChild(node)
                slotNodes[slot.id] = node
                if let item = round.prefilled[slot.id] {
                    let figure = CardNode(id: "pre_\(slot.id)", item: item, size: slotSize, cornerRadius: 12, padding: 6, plain: true)
                    figure.position = node.position
                    figure.isAccessibilityElement = false
                    addChild(figure)
                    node.markFilled()
                }
            }
        }
    }

    private func buildBasket() {
        // prop_basket.png replaces this when it arrives.
        let basket = SKShapeNode(rect: CGRect(x: -330, y: -95, width: 660, height: 190), cornerRadius: 40)
        basket.fillColor = RokkoColor.ui(RokkoColor.honeyWash)
        basket.strokeColor = RokkoColor.ui(RokkoColor.cardEdge)
        basket.lineWidth = 3
        basket.position = design(size.width / 2, 570)
        basket.zPosition = -3
        addChild(basket)
    }

    private func showBatch(_ index: Int, animated: Bool) {
        guard index < round.batches.count else { return }
        let size = CGSize(width: 110, height: 128)
        let batch = round.batches[index]
        for (card, x) in zip(batch, rowCentres(count: batch.count, width: size.width, gap: 28)) {
            let node = CardNode(id: card.id, item: card.item, size: size, padding: 10)
            node.position = design(x, 570)
            node.home = node.position
            batchNode.addChild(node)
            draggables.append(node)
            if animated {
                node.alpha = 0
                node.run(.fadeIn(withDuration: motion.screenFade))
            }
        }
    }

    override func anchor(for id: String) -> (point: CGPoint, size: CGSize)? {
        if let rect = houseRects[id] { return (CGPoint(x: rect.midX, y: rect.midY), rect.size) }
        return super.anchor(for: id)
    }

    override func hintObstacles() -> [CGRect] { super.hintObstacles() + Array(houseRects.values) }

    /// A figure is dragged over a house: honey edge (faint glow) on the whole house.
    override func setHighlight(_ on: Bool, target id: String) {
        guard let panel = housePanels[id] else { return super.setHighlight(on, target: id) }
        panel.strokeColor = RokkoColor.ui(on ? RokkoColor.honey : RokkoColor.cardEdge)
        panel.lineWidth = on ? 5 : 3
    }

    override func dropTarget(for card: CardNode, at point: CGPoint) -> String? {
        let margin = motion.snapDistance
        return houseRects.first { $0.value.insetBy(dx: -margin, dy: -margin).contains(point) }?.key
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
        case .showPart(let index):
            showBatch(index, animated: true)
        default:
            super.show(feedback)
        }
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Type 5 · L1 · two houses", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-05-05", level: 1)
}
#Preview("Type 5 · L6", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-05-05", level: 6)
}
#Preview("Type 5 · L1 · Calm", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-3-05-05", level: 1, calm: true)
}
#endif
