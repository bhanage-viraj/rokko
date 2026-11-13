//
//  GuardianMenu.swift
//  Guardian menu: how the lesson feels, sound, Guardian's turn tips, and "Run setup again".
//  Opened from the gear on the lesson map. Sized to its content.
//

import SwiftUI

struct GuardianMenu: View {
    @Bindable var settings: AppSettings
    let onRunSetupAgain: () -> Void
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

            Button(action: onRunSetupAgain) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .bold))
                    Text("Run setup again")
                        .font(RokkoFont.nunito(20, .bold, scales: true))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RokkoColor.inkSoft)
                }
                .foregroundStyle(RokkoColor.teal)
                .padding(.horizontal, 20)
                .frame(minHeight: 64)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(RokkoColor.card))
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, 28)
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

/// Two-option segmented control in the app's type and colours. Each half is ≥ 56 pt tall.
private struct TwoWayPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { value, title in
                let on = selection == value
                Button { selection = value } label: {
                    Text(title)
                        .font(RokkoFont.nunito(19, on ? .heavy : .semibold, scales: true))
                        .foregroundStyle(on ? RokkoColor.card : RokkoColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(on ? RokkoColor.teal : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                .animation(.easeOut(duration: 0.2), value: on)
            }
        }
        .padding(6)
        .background(Capsule().fill(RokkoColor.tealWash))
    }
}
