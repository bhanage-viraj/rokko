//
//  ClipVideoView.swift
//  The video picture only: an AVPlayerLayer with no controls (Next and Again live in the frame).
//

import AVFoundation
import SwiftUI

struct ClipVideoView: UIViewRepresentable {
    let player: AVPlayer
    /// Fill the space edge to edge (crops a little); otherwise the whole picture fits inside.
    var fills = false

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect
        view.playerLayer.player = player
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.playerLayer.videoGravity = fills ? .resizeAspectFill : .resizeAspect
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
