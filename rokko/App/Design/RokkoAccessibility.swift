//
//  RokkoAccessibility.swift
//  One rule for every screen: with iOS Reduce Motion or Calm mode on, nothing moves, scales or
//  bounces. It only fades. With Reduce Transparency on, frosted layers become solid.
//

import SwiftUI

extension EnvironmentValues {
    /// Calm mode (Guardian setting, or a wobbly mood). Set once by the lesson / onboarding container.
    @Entry var rokkoCalm: Bool = false
}

extension View {
    /// `.animation(_:value:)` that turns into a short plain fade under Reduce Motion or Calm.
    func motionSafeAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionSafeAnimation(animation: animation, value: value))
    }

    /// `.transition(_:)` that turns into `.opacity` under Reduce Motion or Calm.
    func motionSafeTransition(_ transition: AnyTransition) -> some View {
        modifier(MotionSafeTransition(transition: transition))
    }
}

private struct MotionSafeAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @MotionStill private var still

    func body(content: Content) -> some View {
        content.animation(still ? .easeInOut(duration: RokkoMotion.stillFade) : animation, value: value)
    }
}

private struct MotionSafeTransition: ViewModifier {
    let transition: AnyTransition
    @MotionStill private var still

    func body(content: Content) -> some View {
        content.transition(still ? .opacity : transition)
    }
}

/// True when views should only fade (Reduce Motion or Calm): `@MotionStill private var still`.
@propertyWrapper
struct MotionStill: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rokkoCalm) private var calm
    init() {}
    var wrappedValue: Bool { reduceMotion || calm }
}
