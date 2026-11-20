//
//  GameHost.swift
//  ONE SKView for the whole lesson (docs/ARCHITECTURE.md): new rounds swap scenes inside the
//  same view with a cross-fade, so there is no flash and textures stay cached.
//

import SwiftUI
import SpriteKit

struct GameHost: UIViewRepresentable {
    let scene: LessonScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: CGRect(origin: .zero, size: RokkoLayoutSize.canvas))
        view.allowsTransparency = true
        view.backgroundColor = .clear
        view.isOpaque = false
        view.ignoresSiblingOrder = false
        view.isMultipleTouchEnabled = false
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        guard view.scene !== scene else { return }
        view.presentScene(scene, transition: .crossFade(withDuration: scene.motion.screenFade))
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Game host · Type 1", traits: .landscapeLeft) {
    ExerciseRoundPreview(code: "001-1-01-01", level: 1)
}
#endif
