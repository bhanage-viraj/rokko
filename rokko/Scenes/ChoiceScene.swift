//
//  ChoiceScene.swift
//  Types 1 · 2: the shown figure at the top (question area, y 150–330), answer cards in one
//  row below (y 400–680). Tap one card. Level 4 uses the smaller 168 × 210 cards (DECISIONS O7).
//

import SpriteKit
import SwiftUI
import RokkoContent
import RokkoEngine

final class ChoiceScene: LessonScene {
    private let round: ChoiceRound

    init(round: ChoiceRound, level: Int, layout: EngineConfig.Layout, motion: SceneMotion) {
        self.round = round
        super.init(motion: motion)

        let shownSize = CGSize(width: 220, height: 248)
        let shown = CardNode(id: "shown", item: round.shown, size: shownSize, padding: 2, plain: true)
        shown.position = design(size.width / 2, 120 + shownSize.height / 2)
        shown.isAccessibilityElement = false
        addChild(shown)

        let dims = level == 4 ? layout.choiceCardLevel4 : layout.choiceCardMin
        let cardSize = CGSize(width: dims[0], height: dims[1])
        let gap: CGFloat = round.cards.count >= 6 ? 16 : 32
        let xs = rowCentres(count: round.cards.count, width: cardSize.width, gap: gap)
        let y = 400 + (280 - cardSize.height) / 2 + cardSize.height / 2
        for (card, x) in zip(round.cards, xs) {
            let node = CardNode(id: card.id, item: card.item, size: cardSize)
            node.position = design(x, y)
            node.home = node.position
            addChild(node)
            tappables.append(node)
        }
    }

    override func show(_ feedback: Feedback) {
        switch feedback {
        case .correct(let id):
            card(id)?.showCorrect(motion)
        case .tryAgain(let id):
            card(id)?.showTryAgain(motion)
        case .dimAllExcept(let id):
            for node in tappables where node.cardId != id && !node.isSunk { node.dim(motion) }
        default:
            super.show(feedback)
        }
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Type 1 · L1 · choice row", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-01-01", level: 1)
}
#Preview("Type 1 · L4 · all six", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-01-01", level: 4)
}
#Preview("Type 1 · L5 · white & black", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-01-01", level: 5)
}
#Preview("Type 2 · L1 · choice row", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-02-04", level: 1)
}
#Preview("Type 1 · L1 · Calm", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-01-01", level: 1, calm: true)
}
#endif
