//
//  UIReviewView.swift
//  Developer › UI/UX check: one round per distinct screen layout (10 in all), grouped by exercise
//  type. Levels that only change the content reuse one of these layouts and are left out.
//  Next in the player goes to the next layout in this list.
//  Opened from Guardian menu › Developer. Not part of the lesson flow; children never see it.
//

import SwiftUI
import RokkoContent

/// One distinct layout: the first round of `level` in exercise `code`.
struct UIReviewItem: Identifiable, Hashable {
    let code: String
    let level: Int
    let title: String
    let detail: String
    var id: String { "\(code)-\(level)" }
}

struct UIReviewSection: Identifiable {
    let title: String
    let items: [UIReviewItem]
    var id: String { title }
}

enum UIReviewCatalogue {
    /// Hand-picked from docs/EXERCISES.md and the scenes' layout rules. Entries missing from the
    /// pool are dropped, so a pool change never crashes this screen.
    static func sections(pool: ExercisePool, maxLevel: Int) -> [UIReviewSection] {
        // One entry per distinct screen layout. Everything else in the pool reuses one of these.
        let all: [UIReviewSection] = [
            UIReviewSection(title: "Type 1 · Character → piece", items: [
                UIReviewItem(code: "001-1-01-01", level: 1, title: "Choice row", detail: "Character shown, piece cards in a row. Levels 1–3, 5–6 use this layout."),
                UIReviewItem(code: "001-1-01-01", level: 4, title: "All six", detail: "Six cards, level-4 card size, tighter gap."),
            ]),
            UIReviewSection(title: "Type 2 · Piece → character", items: [
                UIReviewItem(code: "001-1-02-04", level: 1, title: "Choice row", detail: "Piece shown, character cards in a row."),
            ]),
            UIReviewSection(title: "Type 3 · Linking", items: [
                UIReviewItem(code: "001-3-03-01", level: 1, title: "Two columns", detail: "Animals left, pieces right. Levels 1–3."),
                UIReviewItem(code: "001-3-03-01", level: 4, title: "Two parts", detail: "10 pairs; part 1 fades to part 2."),
                UIReviewItem(code: "001-3-03-01", level: 5, title: "Four rows", detail: "White and black, 6 + 6."),
                UIReviewItem(code: "001-3-03-01", level: 6, title: "Shaded middle", detail: "Shaded characters between white and black pieces."),
            ]),
            UIReviewSection(title: "Type 4 · Team shelf", items: [
                UIReviewItem(code: "001-3-04-03", level: 1, title: "Shelf", detail: "One team's shelf. Levels 1–5."),
                UIReviewItem(code: "001-3-04-03", level: 6, title: "Shelf + other colour", detail: "Distractors stay off the shelf."),
            ]),
            UIReviewSection(title: "Type 5 · Both teams", items: [
                UIReviewItem(code: "001-3-05-05", level: 1, title: "Two houses", detail: "White and black houses, figures in batches."),
            ]),
        ]
        return all.compactMap { section in
            let items = section.items.filter {
                $0.level <= maxLevel && !(pool.exercise($0.code)?.rounds(level: $0.level).isEmpty ?? true)
            }
            return items.isEmpty ? nil : UIReviewSection(title: section.title, items: items)
        }
    }
}

struct UIReviewView: View {
    @Binding var calm: Bool
    let onClose: () -> Void

    var body: some View {
        switch ContentLibrary.shared {
        case .success(let library):
            UIReviewGallery(library: library, calm: $calm, onClose: onClose)
        case .failure(let error):
            NavigationStack {
                ContentUnavailableView("Content could not load", systemImage: "exclamationmark.triangle",
                                       description: Text(error.description))
                    .toolbar { Button("Done", action: onClose) }
            }
        }
    }
}

private struct UIReviewGallery: View {
    let library: ContentLibrary
    @Binding var calm: Bool
    let onClose: () -> Void

    @State private var playing: UIReviewItem?
    @State private var learner: DevLearner?

    private var sections: [UIReviewSection] { UIReviewCatalogue.sections(pool: library.pool, maxLevel: library.config.levels.maxLevel) }
    private var flat: [UIReviewItem] { sections.flatMap(\.items) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("One round of every layout that looks different. Next in the player goes to the next layout.")
                        .foregroundStyle(.secondary)
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.title).font(.title3.bold())
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                                ForEach(section.items) { item in card(item) }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("UI/UX check")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done", action: onClose) }
                ToolbarItem(placement: .primaryAction) { LookPicker(calm: $calm) }
                ToolbarItem(placement: .primaryAction) {
                    Button { playing = flat.first } label: { Label("Play all", systemImage: "play.fill") }
                        .disabled(flat.isEmpty)
                }
            }
        }
        .tint(RokkoColor.teal)
        .fullScreenCover(item: $playing) { item in
            if let ex = library.pool.exercise(item.code) {
                ExercisePlayerView(library: library, exercise: ex, level: item.level, index: 0,
                                   calm: $calm, learner: devLearner, onClose: { playing = nil },
                                   onNext: { advance(from: item) },
                                   reviewLabel: label(for: item))
                    .id(item.id)
            }
        }
    }

    private func card(_ item: UIReviewItem) -> some View {
        Button { playing = item } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title).font(.headline)
                    Spacer()
                    Image(systemName: "play.fill")
                }
                Text(item.detail).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("\(item.code) · level \(item.level)").font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    private func label(for item: UIReviewItem) -> String {
        let n = (flat.firstIndex(of: item) ?? 0) + 1
        return "\(item.title) · \(n) of \(flat.count)"
    }

    /// Next layout in the list; after the last one, back to the gallery.
    private func advance(from item: UIReviewItem) {
        guard let i = flat.firstIndex(of: item), i + 1 < flat.count else { playing = nil; return }
        playing = flat[i + 1]
    }

    /// One BKT learner for this visit (the player needs one; nothing is saved).
    private var devLearner: DevLearner {
        if let learner { return learner }
        let made = DevLearner(config: library.config)
        DispatchQueue.main.async { learner = made }
        return made
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Developer · UI/UX check", traits: .landscapeLeft) {
    @Previewable @State var calm = true
    UIReviewView(calm: $calm, onClose: {})
}
#endif
