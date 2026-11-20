//
//  ItemArt.swift
//  Texture + tint for an Item, named as in docs/ASSETS.md.
//  Ivory art is used as-is. Charcoal: the charcoal PNG when it exists, otherwise the ivory PNG
//  tinted slate (characters mirrored to face left). Shaded (Type 3 L6): ivory tinted grey-brown.
//  A missing PNG never shows SpriteKit's placeholder: the node draws the piece name instead.
//

import SpriteKit
import SwiftUI
import UIKit
import RokkoContent

enum ItemArt {
    static func imageName(_ item: Item, colour: String) -> String {
        switch item.form {
        case .character: "char_\(item.piece.animal)_\(colour)"
        case .piece: "piece_\(item.piece.rawValue)_\(colour)"
        }
    }

    struct Look {
        let texture: SKTexture?
        let tint: UIColor?
        let tintFactor: CGFloat
        let mirrored: Bool
        let fallbackText: String
    }

    private static var cache: [String: SKTexture] = [:]

    private static func texture(_ name: String) -> SKTexture? {
        if let t = cache[name] { return t }
        guard let image = UIImage(named: name) else { return nil }
        let t = SKTexture(image: image)
        cache[name] = t
        return t
    }

    static func look(for item: Item) -> Look {
        let fallback = item.form == .character ? item.piece.animal.capitalized : item.piece.displayName
        switch item.colour {
        case .white:
            return Look(texture: texture(imageName(item, colour: "ivory")), tint: nil, tintFactor: 0,
                        mirrored: false, fallbackText: fallback)
        case .black:
            if let real = texture(imageName(item, colour: "charcoal")) {
                return Look(texture: real, tint: nil, tintFactor: 0, mirrored: false, fallbackText: fallback)
            }
            return Look(texture: texture(imageName(item, colour: "ivory")),
                        tint: RokkoColor.ui(RokkoColor.charcoalTint), tintFactor: 0.78,
                        mirrored: item.form == .character, fallbackText: fallback)
        case .shaded:
            return Look(texture: texture(imageName(item, colour: "ivory")),
                        tint: RokkoColor.ui(RokkoColor.shadeTint), tintFactor: 0.85,
                        mirrored: false, fallbackText: fallback)
        }
    }

    /// A sprite (or label) fitted inside `box`, centred on (0, 0).
    static func node(for item: Item, fitting box: CGSize) -> SKNode {
        let look = look(for: item)
        guard let texture = look.texture else {
            let label = SKLabelNode(text: look.fallbackText)
            label.fontName = "Fredoka-SemiBold"
            label.fontSize = min(26, box.width / 4)
            label.fontColor = RokkoColor.ui(item.colour == .white ? RokkoColor.ink : RokkoColor.charcoalTint)
            label.verticalAlignmentMode = .center
            return label
        }
        let sprite = SKSpriteNode(texture: texture)
        let scale = min(box.width / texture.size().width, box.height / texture.size().height)
        sprite.size = CGSize(width: texture.size().width * scale, height: texture.size().height * scale)
        if let tint = look.tint {
            sprite.color = tint
            sprite.colorBlendFactor = look.tintFactor
        }
        if look.mirrored { sprite.xScale = -1 }
        return sprite
    }
}

// MARK: - Clue halves

/// Which part of an animal / piece the Hint 1 clue card shows. The two halves meet at a seam, faces
/// (or, for the Rook, the two halves of one tower) touching it.
struct ClueHalf {
    /// Faces left instead of right (characters are normalised to face right first).
    var facesLeft = false
    /// Kept slice of the art, as fractions of its width (0 = left edge).
    var from: CGFloat
    var to: CGFloat
    /// Top-align (tower tops meet) instead of standing on the bottom edge.
    var alignTop = false

    /// Elephant: tower centre on its back as a share of the art width, measured on the 14 Nov 1024 px art
    /// (ivory 0.530, charcoal 0.514), mirrored because the clue turns the elephant to face left.
    private static let elephantTowerX: CGFloat = 1 - 0.52

    /// Animal, left of the seam. Default: right-facing front half (head, no tail), head at the seam.
    /// Elephant: faces left, cut through the tower on its back, so its half tower meets the Rook's.
    static func animal(_ p: Piece) -> ClueHalf {
        p == .rook ? ClueHalf(facesLeft: true, from: 0, to: elephantTowerX, alignTop: true)
                   : ClueHalf(from: 0.5, to: 1)
    }

    /// Piece, right of the seam. Default: left half (the Knight's face) at the seam.
    /// Rook: right half, so the cut through its tower is at the seam.
    static func piece(_ p: Piece) -> ClueHalf {
        p == .rook ? ClueHalf(from: 0.5, to: 1, alignTop: true) : ClueHalf(from: 0, to: 0.5)
    }

    /// The cropped half, scaled to fill `half` (one side of the card: half.width / 2 × half.height), placed
    /// with its seam edge at x = 0. Returns the node and its width.
    func node(for item: Item, half: CGSize, leftOfSeam: Bool) -> (node: SKNode, width: CGFloat) {
        let art = ItemArt.node(for: item, fitting: half)
        if item.form == .character { art.xScale = abs(art.xScale) }            // face right
        if facesLeft { art.xScale = -abs(art.xScale) }
        let frame = art.calculateAccumulatedFrame()
        let partWidth = max((to - from) * frame.width, 1)
        let scale = min(half.width / 2 / partWidth, half.height / frame.height)
        let holder = SKNode()
        holder.setScale(scale)
        holder.addChild(art)

        let minX = (frame.minX + from * frame.width) * scale
        let maxX = (frame.minX + to * frame.width) * scale
        let height = frame.height * scale
        let mask = SKSpriteNode(color: .white, size: CGSize(width: maxX - minX, height: height + 4))
        mask.position = CGPoint(x: (minX + maxX) / 2, y: frame.midY * scale)
        let crop = SKCropNode()
        crop.maskNode = mask
        crop.addChild(holder)

        let dy = alignTop ? half.height / 2 - frame.maxY * scale : -half.height / 2 - frame.minY * scale
        crop.position = CGPoint(x: leftOfSeam ? -maxX : -minX, y: dy)
        return (crop, maxX - minX)
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("All item art", traits: .landscapeLeft) {
    SpriteNodePreview(size: CGSize(width: 1194, height: 834)) { scene, _, design in
        let rows: [(ItemColour, ItemForm)] = [(.white, .character), (.white, .piece), (.black, .character),
                                               (.black, .piece), (.shaded, .character), (.shaded, .piece)]
        let box = CGSize(width: 100, height: 110)
        for (r, (colour, form)) in rows.enumerated() {
            let y = 75 + CGFloat(r) * 130
            let tag = SpriteNodePreview.label("\(colour.rawValue) \(form.rawValue)", at: design(130, y))
            scene.addChild(tag)
            for (i, piece) in Piece.allCases.enumerated() {
                let node = ItemArt.node(for: Item(colour, form, piece), fitting: box)
                node.position = design(300 + CGFloat(i) * 150, y)
                scene.addChild(node)
            }
        }
    }
}
#endif
