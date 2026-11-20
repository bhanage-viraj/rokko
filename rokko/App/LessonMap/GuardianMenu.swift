//
//  GuardianMenu.swift
//  Guardian menu: how the lesson feels, sound and Guardian's turn tips.
//  Opened from the gear on the lesson map. Sized to its content.
//  The developer screens (all exercises, UI/UX check) open only from DEBUG launch arguments.
//

import SwiftUI
import SwiftData

struct GuardianMenu: View {
    @Bindable var settings: AppSettings
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Guardian menu")
                    .font(RokkoFont.fredoka(30, scales: true))
                    .foregroundStyle(RokkoColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done", action: onClose)
                    .font(RokkoFont.nunito(20, .heavy, scales: true))
                    .foregroundStyle(RokkoColor.teal)
                    .frame(minWidth: 56, minHeight: 56)
            }

            MenuSection(title: "How the lesson feels") {
                TwoWayPicker(selection: $settings.calm,
                             options: [(true, "Calm"), (false, "Standard")])
                    .padding(16)
                MenuDivider()
                Toggle(isOn: $settings.sound) {
                    Text("Sound").font(RokkoFont.nunito(20, .semibold, scales: true))
                }
                .tint(RokkoColor.teal)
                .padding(.horizontal, 20)
                .frame(minHeight: 64)
            }

            MenuSection(title: "Guardian's turn") {
                TwoWayPicker(selection: Binding(get: { settings.tipsMode },
                                                set: { settings.tipsMode = $0 }),
                             options: [(TipsMode.full, "Full steps"), (.short, "One line")])
                    .padding(16)
            }

        }
        .foregroundStyle(RokkoColor.ink)
        .padding(32)
        .frame(width: 560)
        .background(RokkoColor.mistBlue)
        .presentationSizing(.fitted)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

private struct MenuSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(RokkoFont.nunito(14, .heavy, scales: true))
                .tracking(1.1)
                .foregroundStyle(RokkoColor.teal)
                .padding(.leading, 4)
            VStack(spacing: 0, content: content)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RokkoColor.card))
        }
        .padding(.top, 28)
    }
}

private struct MenuDivider: View {
    var body: some View {
        Rectangle().fill(RokkoColor.mistEdgeSoft).frame(height: 1).padding(.leading, 20)
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
