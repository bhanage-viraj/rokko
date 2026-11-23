//
//  ParallaxConfigTests.swift
//  Parallax speeds (lesson map and lesson steps) in RokkoMotion mirror EngineConfig.json › motion.
//

import Foundation
import Testing
import RokkoContent
@testable import rokko

@MainActor
struct ParallaxConfigTests {
    @Test func parallaxSpeedsMirrorEngineConfig() throws {
        let motion = try ContentLibrary(bundle: .main).config.motion
        #expect(Double(RokkoMotion.homeParallaxFar) == motion.homeParallaxFar)
        #expect(Double(RokkoMotion.homeParallaxMid) == motion.homeParallaxMid)
        #expect(Double(RokkoMotion.homeParallaxCardArt) == motion.homeParallaxCardArt)
        #expect(RokkoMotion.stepSlide * 1000 == motion.stepSlideMs)
        #expect(Double(RokkoMotion.stepSlideShare) == motion.stepSlideShare)
        #expect(Double(RokkoMotion.stepParallaxBackground) == motion.stepParallaxBackground)
        #expect(motion.stepParallaxBackground < 1)
        // Far layers move slowest, the card (1.0) fastest.
        #expect(motion.homeParallaxCardArt < 1 && motion.homeParallaxFar < motion.homeParallaxMid && motion.homeParallaxMid < 1)
    }
}
