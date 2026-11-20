//
//  GuardianComponents.swift
//  Shared pieces for the blue Guardian screens (setup, lesson map, Guardian's turn).
//

import SwiftUI

// MARK: - Canvas

/// Lays content out on the fixed 1194 × 834 design canvas and scales it to fit the iPad.
/// `fills: true` (lesson screens): the canvas grows to the iPad's own shape instead of leaving empty
/// bands, at the same scale. Views read the grown size from `\.canvasSize`.
struct DesignCanvas<Content: View>: View {
    var background: Color = RokkoColor.mistBlue
    var fills = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let design = RokkoLayout.canvas
            let scale = min(geo.size.width / design.width, geo.size.height / design.height)
            let size = fills ? CGSize(width: geo.size.width / scale, height: geo.size.height / scale) : design
            ZStack {
                background
                PaperGrain()
                content()
                    .environment(\.canvasSize, size)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }
}

extension EnvironmentValues {
    /// Size of the design canvas in design points: 1194 × 834, or larger on iPads of another shape
    /// when the canvas fills the screen.
    @Entry var canvasSize: CGSize = RokkoLayout.canvas
}

/// Paper grain overlay (`tex_noise`) used on every surface in the design.
struct PaperGrain: View {
    var opacity: Double = 0.7
    var body: some View {
        Image("tex_noise")
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Text

/// The Guardian's symbol: the same glyph as the Guardian button, so a Guardian screen is
/// recognisable before anyone reads it.
enum GuardianSymbol {
    static let name = "person.2.fill"
}

/// "👥 GUARDIAN" pill above every Guardian title and on every Guardian's turn.
struct GuardianLabel: View {
    var text: String = "Guardian"
    var fontSize: CGFloat = 16
    var fill: Color = RokkoColor.card
    var body: some View {
        HStack(spacing: fontSize * 0.5) {
            Image(systemName: GuardianSymbol.name)
                .font(.system(size: fontSize * 1.1, weight: .bold))
                .accessibilityHidden(true)
            Text(text.uppercased())
                .tracking(fontSize * 0.08)
        }
        .font(RokkoFont.nunito(fontSize, .black))
        .foregroundStyle(RokkoColor.teal)
        .padding(.horizontal, fontSize)
        .padding(.vertical, fontSize * 0.45)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(RokkoColor.mistEdge, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }
}

struct GuardianTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(RokkoFont.fredoka(44))
            .foregroundStyle(RokkoColor.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct GuardianBody: View {
    let text: String
    var body: some View {
        Text(text)
            .font(RokkoFont.nunito(21))
            .lineSpacing(4)
            .foregroundStyle(RokkoColor.inkSoft)
    }
}

/// Label + title (+ optional body), the header block of every setup screen.
struct GuardianHeader: View {
    let label: String
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GuardianLabel(text: label)
            GuardianTitle(text: title)
            if let detail { GuardianBody(text: detail) }
        }
    }
}

// MARK: - Buttons

/// Leaf-green pill with an arrow. Used for Next, Done, I'm ready, Continue.
struct PrimaryButton: View {
    let title: String
    var height: CGFloat = RokkoLayout.primaryButtonHeight
    var fontSize: CGFloat = 28
    var cornerRadius: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                Image(systemName: "arrow.right")
                    .font(.system(size: fontSize * 0.8, weight: .heavy))
                    .accessibilityHidden(true)
            }
            .font(RokkoFont.fredoka(fontSize))
            .foregroundStyle(RokkoColor.card)
            .padding(.horizontal, 32)
            .frame(minWidth: 180, minHeight: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RokkoColor.leaf)
                    .shadow(color: RokkoColor.leaf.opacity(0.22), radius: 7, y: 6)
            )
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Outlined pill (secondary action): card fill, 3 pt leaf border.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var trailingArrow = false
    var height: CGFloat = 56
    var fontSize: CGFloat = 20
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: fontSize, weight: .bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                if trailingArrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: fontSize * 0.9, weight: .heavy))
                        .accessibilityHidden(true)
                }
            }
            .font(RokkoFont.fredoka(fontSize))
            .foregroundStyle(RokkoColor.leaf)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Capsule().fill(RokkoColor.card))
            .overlay(Capsule().strokeBorder(RokkoColor.leaf, lineWidth: 3))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// Card press: scale 0.97 over 120 ms. Reduce Motion: no scale, a soft fade instead.
struct PressScaleStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.85 : 1)
            .animation(.easeOut(duration: RokkoMotion.press), value: configuration.isPressed)
    }
}

/// Places the primary button in its fixed spot: bottom-right, right 40, top 698.
struct PrimaryButtonSlot<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.trailing, RokkoLayout.margin)
            .padding(.bottom, RokkoLayout.primaryButtonBottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}

/// Back, Skip, Settings: teal symbol in a soft round button, 56 pt touch target, VoiceOver label.
struct GuardianIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(RokkoColor.teal)
                .frame(width: 56, height: 56)
                .background(Circle().fill(RokkoColor.card))
                .overlay(Circle().strokeBorder(RokkoColor.mistEdge, lineWidth: 2))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Cards

extension View {
    /// Rounded card: card fill + grain, border, warm soft shadow.
    func rokkoCard(radius: CGFloat = 28,
                   edge: Color = RokkoColor.cardEdge,
                   edgeWidth: CGFloat = 3,
                   fill: Color = RokkoColor.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(fill)
            .clipShape(shape)
            .overlay(shape.strokeBorder(edge, lineWidth: edgeWidth))
            .background(shape.fill(fill).shadow(color: RokkoColor.ink.opacity(0.10), radius: 8, y: 6))
    }

    /// Absolute placement on the design canvas (top-left origin, design points).
    func place(x: CGFloat, y: CGFloat) -> some View {
        offset(x: x, y: y)
    }
}

/// Soft oval ground shadow under a character.
struct GroundShadow: View {
    var body: some View {
        Ellipse()
            .fill(RokkoColor.leaf.opacity(0.16))
            .blur(radius: 6)
            .accessibilityHidden(true)
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Guardian components", traits: .landscapeLeft) {
    DesignCanvas {
        VStack(alignment: .leading, spacing: 24) {
            GuardianHeader(label: "For the Guardian", title: "Your lessons",
                           detail: "Sit next to your child with the real board.")
            GuardianBody(text: "Guardian body text, 20 pt.")
            HStack(spacing: 16) {
                PrimaryButton(title: "Start lesson") {}.frame(width: 320)
                SecondaryButton(title: "Run setup again", systemImage: "arrow.counterclockwise") {}.frame(width: 320)
                GuardianIconButton(systemName: "gearshape.fill", label: "Settings") {}
            }
            GroundShadow()
        }
        .padding(64)
    }
}
#endif
