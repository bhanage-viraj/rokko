//
//  GuardianMenu.swift
//  Settings (Guardian): Calm / Standard and sound.
//  Opened from the gear on the lesson map. Sized to its content.
//  The developer screens (all exercises, UI/UX check) open only from DEBUG launch arguments.
//

import SwiftUI
import SwiftData

struct GuardianMenu: View {
    @Bindable var settings: AppSettings
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header: title and a round close button.
            HStack {
                Text("Settings")
                    .font(RokkoFont.fredoka(30, scales: true))
                    .foregroundStyle(RokkoColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(RokkoColor.ink)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(RokkoColor.card))
                        .overlay(Circle().strokeBorder(RokkoColor.mistEdge, lineWidth: 2))
                        .frame(width: 56, height: 56)   // touch target
                        .contentShape(Circle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel("Close")
            }

            TwoWayPicker(selection: $settings.calm,
                         options: [(true, "Calm"), (false, "Standard")])
                .accessibilityLabel("How the lesson feels")

            Toggle(isOn: $settings.sound) {
                Text("Sound").font(RokkoFont.nunito(20, .semibold, scales: true))
            }
            .tint(RokkoColor.teal)
            .padding(.horizontal, 20)
            .frame(minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RokkoColor.card))
        }
        .foregroundStyle(RokkoColor.ink)
        .padding(28)
        .frame(width: 420)
        .background(RokkoColor.mistBlue)
        .presentationSizing(.fitted)
        // The sheet's own background, so it never shows dark bands around the content.
        .presentationBackground(RokkoColor.mistBlue)
        .presentationCornerRadius(36)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// Two-option switch: the system segmented control, so its thumb is real Liquid Glass (it lifts
/// into glass and slides as the Guardian drags or taps). Fonts and colours come from RokkoTheme.
private struct TwoWayPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.0) { value, title in
                Text(title).tag(value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.extraLarge)
        .onAppear(perform: Self.styleOnce)
    }

    /// Rokko type on the segments: Nunito, ink, white on the teal thumb.
    private static func styleOnce() {
        let look = UISegmentedControl.appearance(whenContainedInInstancesOf: [UIViewController.self])
        look.selectedSegmentTintColor = UIColor(RokkoColor.teal)
        func nunito(_ weight: UIFont.Weight) -> UIFont {
            let d = UIFontDescriptor(fontAttributes: [.family: "Nunito", .traits: [UIFontDescriptor.TraitKey.weight: weight]])
            return UIFont.familyNames.contains("Nunito") ? UIFont(descriptor: d, size: 19)
                                                          : .systemFont(ofSize: 19, weight: weight)
        }
        let font = nunito(.semibold)
        let bold = nunito(.heavy)
        look.setTitleTextAttributes([.font: font, .foregroundColor: UIColor(RokkoColor.ink)], for: .normal)
        look.setTitleTextAttributes([.font: bold, .foregroundColor: UIColor(RokkoColor.card)], for: .selected)
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Guardian menu", traits: .landscapeLeft) {
    GuardianMenu(settings: PreviewData.settings(), onClose: {})
        .modelContainer(PreviewData.container)
}
#endif
