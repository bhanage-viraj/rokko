//
//  GuardianButton.swift
//  The Guardian button (top-right of every lesson screen). Nothing happens on a tap.
//  Long press with one finger for 2 s → mood check. A teal ring fills while holding.
//  Letting go early: the ring stops at the share of 2 s actually held, then empties from there.
//

import SwiftUI

struct GuardianButton: View {
    /// The engine suggests a check-in (FR-30): the button glows softly. Nothing else changes.
    var glows = false
    /// Held for the full time.
    var onMoodHold: () -> Void = {}

    @State private var progress: Double = 0
    @State private var pressStart: Date?
    @State private var firedThisPress = false

    private let size: CGFloat = 76
    /// Invisible margin so the hold is easy to land, even when the frame is shown scaled.
    private let touchMargin: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .fill(RokkoColor.card)
                .shadow(color: RokkoColor.ink.opacity(0.14), radius: 6, y: 4)
                .overlay {
                    if glows {
                        Circle().stroke(RokkoColor.honey.opacity(0.7), lineWidth: 8).blur(radius: 4)
                    }
                }
            Image(systemName: "person.2.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(RokkoColor.ink)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(RokkoColor.teal, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(-10)
        }
        .frame(width: size, height: size)
        .coachTarget(.guardian)
        .padding(touchMargin)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: RokkoMotion.moodHoldSeconds, maximumDistance: 30) {
            complete()
        } onPressingChanged: { pressing in
            pressing ? began() : released()
        }
        .padding(-touchMargin)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Guardian")
        .accessibilityHint("Hold for 2 seconds to check in.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Check in") { onMoodHold() }
    }

    // MARK: Hold

    private func began() {
        pressStart = .now
        firedThisPress = false
        progress = 0
        withAnimation(.linear(duration: RokkoMotion.moodHoldSeconds)) { progress = 1 }
    }

    /// Finger up: work out how far the hold really got, and act on that.
    private func released() {
        guard let start = pressStart else { return }
        pressStart = nil
        guard !firedThisPress else { return }
        let held = HoldProgress(elapsed: Date.now.timeIntervalSince(start), holdSeconds: RokkoMotion.moodHoldSeconds)
        if held.isComplete {
            complete()
            return
        }
        // Stop the running fill where the finger actually left it, then empty from there.
        var stop = Transaction()
        stop.disablesAnimations = true
        withTransaction(stop) { progress = held.fraction }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: held.rewindSeconds)) { progress = 0 }
        }
    }

    private func complete() {
        guard !firedThisPress else { return }
        firedThisPress = true
        onMoodHold()
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}

/// How far a hold got, from the time the finger was down.
struct HoldProgress: Equatable {
    let elapsed: TimeInterval
    let holdSeconds: Double

    /// 0…1 of the ring.
    var fraction: Double { holdSeconds > 0 ? min(max(elapsed / holdSeconds, 0), 1) : 1 }
    var isComplete: Bool { fraction >= 1 }
    /// The ring empties faster than it filled: 0.12–0.4 s depending on how far it got.
    var rewindSeconds: Double { min(max(fraction * 0.5, 0.12), 0.4) }
}
