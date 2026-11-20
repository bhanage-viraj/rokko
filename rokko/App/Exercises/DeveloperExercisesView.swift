//
//  DeveloperExercisesView.swift
//  Developer access to every Lesson 1 exercise: pick an exercise, a level and a round, and play it
//  in the real lesson frame. Opened from Guardian menu › Developer. Not part of the lesson flow.
//

import SwiftUI
import RokkoContent

struct DeveloperExercisesView: View {
    /// The saved Calm / Standard setting; switching it here changes it for the whole app.
    @Binding var calm: Bool
    let onClose: () -> Void

    var body: some View {
        switch ContentLibrary.shared {
        case .success(let library):
            ExerciseBrowser(library: library, calm: $calm, onClose: onClose)
        case .failure(let error):
            NavigationStack {
                ContentUnavailableView("Content could not load", systemImage: "exclamationmark.triangle",
                                       description: Text(error.description))
                    .toolbar { Button("Done", action: onClose) }
            }
        }
    }
}

private struct PlayTarget: Identifiable, Hashable {
    let code: String
    let level: Int
    let index: Int
    var id: String { "\(code)-\(level)-\(index)" }
}

private struct ExerciseBrowser: View {
    let library: ContentLibrary
    @Binding var calm: Bool
    let onClose: () -> Void

    @State private var selection: String?
    @State private var level = 1
    @State private var playing: PlayTarget?
    @State private var learner: DevLearner?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(modules, id: \.self) { module in
                    Section("Module \(module)") {
                        ForEach(library.pool.exercises.filter { $0.exerciseCode?.module == module }) { ex in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ExerciseNames.title(ex))
                                Text(ex.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            .tag(ex.code)
                        }
                    }
                }
            }
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done", action: onClose) }
                ToolbarItem(placement: .primaryAction) { LookPicker(calm: $calm) }
            }
        } detail: {
            if let code = selection, let ex = library.pool.exercise(code) {
                detail(ex)
            } else {
                ContentUnavailableView("Pick an exercise", systemImage: "square.grid.2x2")
            }
        }
        .tint(RokkoColor.teal)
        .onAppear(perform: openFromLaunchArguments)
        .fullScreenCover(item: $playing) { target in
            if let ex = library.pool.exercise(target.code) {
                ExercisePlayerView(library: library, exercise: ex, level: target.level, index: target.index,
                                   calm: $calm, learner: devLearner, onClose: { playing = nil })
            }
        }
    }

    /// One BKT learner for this visit to the Developer screen.
    private var devLearner: DevLearner {
        if let learner { return learner }
        let made = DevLearner(config: library.config)
        DispatchQueue.main.async { learner = made }
        return made
    }

    private var modules: [Int] {
        Array(Set(library.pool.exercises.compactMap { $0.exerciseCode?.module })).sorted()
    }

    private func detail(_ ex: PoolExercise) -> some View {
        let rounds = ex.rounds(level: level)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Level", selection: $level) {
                    ForEach(ex.playableLevels(maxLevel: library.config.levels.maxLevel), id: \.self) { Text("Level \($0)").tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(ExerciseNames.levelRule(type: ex.type, level: level))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let possible = ex.level(level)?.possibleVariants {
                        Text("\(rounds.count) of \(possible) possible").font(.footnote).foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    ForEach(Array(rounds.enumerated()), id: \.element.id) { i, round in
                        Button {
                            playing = PlayTarget(code: ex.code, level: level, index: i)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Round \(i + 1)").font(.headline)
                                    Spacer()
                                    Image(systemName: "play.fill")
                                }
                                Text(round.id).font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text(ExerciseNames.summary(round)).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(3).multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ExerciseNames.title(ex))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    playing = PlayTarget(code: ex.code, level: level, index: 0)
                } label: {
                    Label("Play level \(level)", systemImage: "play.fill")
                }
            }
        }
        .onChange(of: selection) { level = 1 }
    }

    /// DEBUG: `-RokkoPlayRound 001-1-01-01-3-011` opens that round straight away.
    private func openFromLaunchArguments() {
        if selection == nil { selection = library.pool.exercises.first?.code }
        #if DEBUG
        guard let id = UserDefaults.standard.string(forKey: "RokkoPlayRound"),
              let code = ExerciseCode(id), let level = code.level,
              let ex = library.pool.exercise(code.exerciseOnly),
              let index = ex.rounds(level: level).firstIndex(where: { $0.id == id }) else { return }
        selection = ex.code
        self.level = level
        playing = PlayTarget(code: ex.code, level: level, index: index)
        #endif
    }
}

/// Calm / Standard switch for testing. Same setting as Guardian menu › How the lesson feels.
struct LookPicker: View {
    @Binding var calm: Bool

    var body: some View {
        Picker("Look", selection: $calm) {
            Text("Calm").tag(true)
            Text("Standard").tag(false)
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .accessibilityLabel("Look: Calm or Standard")
    }
}

extension PoolExercise {
    /// Pool levels that are on: none above EngineConfig › levels.maxLevel (1 for now).
    func playableLevels(maxLevel: Int) -> [Int] {
        levelNumbers.filter { $0 <= maxLevel }
    }
}

/// Names for the developer list. Guardian-facing only; never shown to the child.
enum ExerciseNames {
    static func title(_ ex: PoolExercise) -> String {
        let first = ex.levelNumbers.first.flatMap { ex.rounds(level: $0).first }
        switch first?.content {
        case .choice(let c):
            let name = c.answer.piece.displayName
            return ex.type == 1 ? "\(name): character → piece" : "\(name): piece → character"
        case .link(let c):
            return "Linking, \(c.characters.first?.colour.rawValue ?? "")"
        case .shelf(let c):
            return "Team shelf, \(c.team.rawValue)"
        case .teams(let c):
            return "Both teams, \(c.whiteKing.form == .character ? "characters" : "pieces")"
        case nil:
            return ex.code
        }
    }

    static func levelRule(type: Int, level: Int) -> String {
        switch type {
        case 1, 2:
            return ["3 options, no look-alike", "3 options, with a look-alike", "4 options",
                    "All six", "4 mixed colours, no black twin", "5 mixed colours, with the black twin"][level - 1]
        case 3:
            return ["4 pairs, one colour", "6 pairs, one colour", "8 pairs, mixed",
                    "10 pairs in two parts", "6 + 6, white and black", "Shaded characters, 12 links"][level - 1]
        case 4:
            return ["Place 6", "Place 8", "Place 10", "Place 13", "Place 16", "Place 16 + 6 of the other colour"][level - 1]
        case 5:
            return ["4 + 4", "6 + 6", "8 + 8", "10 + 10", "12 + 12", "15 + 15"].map { "Place \($0)" }[level - 1]
        default:
            return ""
        }
    }

    static func summary(_ round: PoolRound) -> String {
        func name(_ i: Item) -> String {
            let n = i.form == .character ? i.piece.animal : i.piece.displayName
            return i.colour == .white ? n : "\(i.colour.rawValue) \(n)"
        }
        switch round.content {
        case .choice(let c):
            return c.options.map(name).joined(separator: ", ")
        case .link(let c):
            return c.characters.map(name).joined(separator: ", ")
        case .shelf(let c):
            return "\(c.toPlace.count) to place" + (c.distractors.isEmpty ? "" : ", \(c.distractors.count) of the other colour")
        case .teams(let c):
            return "\(c.toPlace.count) to place"
        }
    }
}

// MARK: - Previews (Xcode canvas: ⌥⌘↩)

#if DEBUG
#Preview("Developer · exercises", traits: .landscapeLeft) {
    @Previewable @State var calm = true
    DeveloperExercisesView(calm: $calm, onClose: {})
}
#endif
