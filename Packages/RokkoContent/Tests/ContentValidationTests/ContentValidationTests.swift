//
//  ContentValidationTests.swift
//  Loads every content file the games use and checks the pool against the level rules
//  in docs/EXERCISES.md. Run after editing any JSON.
//

import Foundation
import Testing
@testable import RokkoContent

enum ContentFiles {
    /// rokko/Content, found from this file's path (Packages/RokkoContent/Tests/ContentValidationTests/).
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("rokko/Content")

    static var pool: ExercisePool { get throws { try ExercisePool.load(from: root.appendingPathComponent("Lesson1/exercise_pool.json")) } }
    static var voice: VoiceLines { get throws { try VoiceLines.load(from: root.appendingPathComponent("Lesson1/voice_lines.csv")) } }
    static var config: EngineConfig { get throws { try EngineConfig.load(from: root.appendingPathComponent("EngineConfig.json")) } }

    static var exerciseCodes: [String] {
        get throws {
            let data = try Data(contentsOf: root.appendingPathComponent("Lesson1/exercises.json"))
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            return (obj["exercises"] as! [[String: Any]]).map { $0["code"] as! String }
        }
    }

    /// From EngineConfig.json › lookAlikes.
    static var lookAlikes: [Piece: Set<Piece>] {
        get throws {
            let data = try Data(contentsOf: root.appendingPathComponent("EngineConfig.json"))
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            var out: [Piece: Set<Piece>] = [:]
            for (k, v) in obj["lookAlikes"] as! [String: Any] {
                guard let p = Piece(rawValue: k), let list = v as? [String] else { continue }
                out[p] = Set(list.compactMap(Piece.init(rawValue:)))
            }
            return out
        }
    }
}

@Suite("Content files")
struct ContentFileTests {
    @Test func poolLoadsAllRounds() throws {
        let pool = try ContentFiles.pool
        #expect(pool.exercises.count == 18)
        #expect(pool.allRounds.count == 690)
        #expect(Set(pool.allRounds.map(\.id)).count == 690)
    }

    @Test func configLoads() throws {
        let c = try ContentFiles.config
        #expect(c.layout.type5BatchSize > 0)
        #expect(c.generator.seedHash == "fnv1a64")
        #expect(c.generator.prng == "splitmix64")
    }

    @Test func everyExerciseHasLevelsOneToSix() throws {
        let pool = try ContentFiles.pool
        for code in try ContentFiles.exerciseCodes {
            let ex = try #require(pool.exercise(code), "\(code) missing from pool")
            #expect(ex.levelNumbers == [1, 2, 3, 4, 5, 6], "\(code)")
            for level in 1...6 { #expect(!ex.rounds(level: level).isEmpty, "\(code) L\(level)") }
        }
    }

    @Test func roundIdsMatchTheirExercise() throws {
        for ex in try ContentFiles.pool.exercises {
            let code = try #require(ExerciseCode(ex.code))
            #expect(code.type == ex.type)
            for level in ex.levelNumbers {
                for r in ex.rounds(level: level) {
                    let rc = try #require(ExerciseCode(r.id))
                    #expect(rc.exerciseOnly == ex.code && rc.level == level && r.level == level, "\(r.id)")
                }
            }
        }
    }

    @Test func voiceLinesParse() throws {
        let v = try ContentFiles.voice
        #expect(v["l1_q_t1_king"]?.text == "Find the King.")
        #expect(v["l1_t4_done"]?.text == "All six pieces are on the shelf!")
    }

    @Test func gameVoiceKeysExist() throws {
        let v = try ContentFiles.voice
        var keys = ["l1_t3_intro", "l1_t4_intro_white", "l1_t4_intro_black", "l1_t4_done",
                    "l1_t5_intro", "l1_t5_white", "l1_t5_black", "l1_t5_done", "l1_h2_lookhere",
                    "l1_cheer_yes", "l1_cheer_welldone", "l1_cheer_thatsright", "l1_cheer_goodjob", "l1_cheer_yougotit",
                    "l1_cheer_great", "l1_finish_hooray", "l1_finish_youdidit", "l1_finish_wonderful", "l1_finish_greatwork",
                    "l1_enc_okay", "l1_enc_tryagain", "l1_enc_keepgoing", "l1_enc_youcan", "l1_enc_letstry", "l1_enc_taketime"]
        for p in Piece.allCases {
            keys += ["l1_q_t1_\(p.rawValue)", "l1_q_t1w_\(p.rawValue)", "l1_q_t2_\(p.animal)", "l1_q_t2w_\(p.animal)",
                     "l1_rw_\(p.rawValue)", "l1_ln_\(p.rawValue)", "l1_t4_count_\(p.rawValue)",
                     "l1_h3_piece_\(p.rawValue)", "l1_h3_animal_\(p.animal)", "l1_h1_match_\(p.rawValue)"]
        }
        // Full-team shelf (piece figures): "Two Rooks!", "Eight Pawns!", "All sixteen pieces…".
        keys += ["l1_t4_count_rook_2", "l1_t4_count_bishop_2", "l1_t4_count_knight_2", "l1_t4_count_pawn_8", "l1_t4_done_full"]
        for k in keys { #expect(v[k] != nil, "missing voice line \(k)") }
    }
}

@Suite("Pool obeys the level rules")
struct PoolRuleTests {
    @Test func choiceRounds() throws {
        let pool = try ContentFiles.pool
        let lookAlikes = try ContentFiles.lookAlikes
        let optionCount = [1: 3, 2: 3, 3: 4, 4: 6, 5: 4, 6: 5]
        for r in pool.allRounds {
            guard case .choice(let c) = r.content else { continue }
            let id = r.id
            #expect(c.options.count == optionCount[r.level], "\(id) option count")
            #expect(c.options.filter { $0 == c.answer }.count == 1, "\(id) answer once")
            #expect(Set(c.options).count == c.options.count, "\(id) duplicates")
            #expect(c.answer.colour == .white && c.shown.colour == .white, "\(id) target white")
            #expect(c.answer.piece == c.shown.piece && c.answer.form != c.shown.form, "\(id) answer matches shown")
            #expect(c.options.allSatisfy { $0.form == c.answer.form }, "\(id) one form")
            let twin = Item(.black, c.answer.form, c.answer.piece)
            let wrongPieces = Set(c.options.filter { $0 != c.answer && $0.colour == .white }.map(\.piece))
            let similar = lookAlikes[c.answer.piece] ?? []
            switch r.level {
            case 1:
                #expect(wrongPieces.isDisjoint(with: similar), "\(id) L1 has a look-alike")
            case 2:
                #expect(!wrongPieces.isDisjoint(with: similar), "\(id) L2 lacks a look-alike")
            case 1...4:
                #expect(c.options.allSatisfy { $0.colour == .white }, "\(id) same colour")
            case 5:
                #expect(!c.options.contains(twin), "\(id) L5 has twin")
                #expect(c.options.contains { $0.colour == .black }, "\(id) L5 mixed")
            case 6:
                #expect(c.options.contains(twin), "\(id) L6 lacks twin")
            default: break
            }
            if r.level == 4 { #expect(Set(c.options.map(\.piece)) == Set(Piece.allCases), "\(id) all six") }
        }
    }

    @Test func linkRounds() throws {
        let pairCount = [1: 4, 2: 6, 3: 8, 4: 10, 5: 12, 6: 6]
        for r in try ContentFiles.pool.allRounds {
            guard case .link(let c) = r.content else { continue }
            #expect(c.pairs.count == pairCount[r.level], "\(r.id)")
            for pair in c.pairs {
                #expect(pair.pieces.allSatisfy { $0.piece == pair.character.piece }, "\(r.id)")
                if r.level == 6 {
                    #expect(pair.character.colour == .shaded && Set(pair.pieces.map(\.colour)) == [.white, .black], "\(r.id)")
                } else {
                    #expect(pair.pieces.count == 1 && pair.pieces[0].colour == pair.character.colour, "\(r.id)")
                }
            }
        }
    }

    @Test func shelfRounds() throws {
        let toPlace = [1: 6, 2: 8, 3: 10, 4: 13, 5: 16, 6: 16]
        for r in try ContentFiles.pool.allRounds {
            guard case .shelf(let c) = r.content else { continue }
            #expect(c.toPlace.count == toPlace[r.level], "\(r.id)")
            let team = c.toPlace + c.prefilled
            for p in Piece.allCases { #expect(team.filter { $0.piece == p }.count == p.countInTeam, "\(r.id) \(p)") }
            #expect(team.allSatisfy { $0.colour == c.team }, "\(r.id)")
            #expect(c.distractors.allSatisfy { $0.colour != c.team }, "\(r.id)")
            #expect(c.distractors.count == (r.level == 6 ? 6 : 0), "\(r.id)")
        }
    }

    @Test func teamsRounds() throws {
        let each = [1: 4, 2: 6, 3: 8, 4: 10, 5: 12, 6: 15]
        for r in try ContentFiles.pool.allRounds {
            guard case .teams(let c) = r.content else { continue }
            for (colour, king, pre) in [(ItemColour.white, c.whiteKing, c.prefilledWhite), (.black, c.blackKing, c.prefilledBlack)] {
                let placing = c.toPlace.filter { $0.colour == colour }
                #expect(placing.count == each[r.level], "\(r.id)")
                let team = [king] + placing + pre
                for p in Piece.allCases { #expect(team.filter { $0.piece == p }.count == p.countInTeam, "\(r.id) \(p)") }
                #expect(team.allSatisfy { $0.colour == colour }, "\(r.id)")
            }
        }
    }
}

@Suite("Lesson steps")
struct LessonStepTests {
    static var lesson: Lesson { get throws { try Lesson.load(from: ContentFiles.root.appendingPathComponent("Lesson1/lesson1.json")) } }
    static var manifest: ClipManifest { get throws { try ClipManifest.load(from: ContentFiles.root.appendingPathComponent("Lesson1/manifest.json")) } }

    @Test func lessonLoads() throws {
        let lesson = try Self.lesson
        #expect(lesson.steps.count == 34)
        #expect(Set(lesson.steps.map(\.id)).count == lesson.steps.count)
        #expect(lesson.steps.first?.kind == .film)
        #expect(lesson.steps.last?.kind == .complete)
    }

    @Test func everyVoiceKeyInTheLessonExists() throws {
        let voice = try ContentFiles.voice
        let lesson = try Self.lesson
        let steps = lesson.steps + Array(lesson.inserted.values)
        for step in steps {
            for key in step.voice + [step.intro].compactMap({ $0 }) {
                #expect(voice[key] != nil, "\(step.id): missing voice line \(key)")
            }
        }
    }

    @Test func everyClipIsInTheManifest() throws {
        let manifest = try Self.manifest
        let lesson = try Self.lesson
        for step in lesson.steps + Array(lesson.inserted.values) {
            guard let clip = step.clip else { continue }
            let entry = manifest.clip(clip)
            #expect(entry != nil, "\(step.id): clip \(clip) not in manifest.json")
            #expect(entry?.files["calm"] != nil && entry?.files["standard"] != nil, "\(clip): needs calm and standard files")
        }
    }

    @Test func gameBlocksPointAtRealGatesAndInsertedSteps() throws {
        let config = try ContentFiles.config
        let lesson = try Self.lesson
        for step in lesson.steps where step.kind == .gameBlock {
            #expect(step.module != nil)
            #expect(step.gate.flatMap { config.gates[$0] } != nil, "\(step.id): unknown gate")
            #expect(config.planner.blocks["module\(step.module ?? 0)"] != nil, "\(step.id): no planner block")
            for key in step.insertsOnce.values { #expect(lesson.inserted[key] != nil, "\(step.id): unknown inserted step \(key)") }
        }
        for step in lesson.steps where step.kind == .guardianShow { #expect(step.piece != nil) }
        for step in lesson.steps where step.kind == .guardianModule { #expect(!step.pieces.isEmpty) }
    }

    /// A missing asset fails here, not at runtime (docs/ASSETS.md › Audio).
    @Test func everyVoiceLineIsRecorded() throws {
        let folder = ContentFiles.root.deletingLastPathComponent().appendingPathComponent("Resources/Audio/Voice")
        let csv = try String(contentsOf: ContentFiles.root.appendingPathComponent("Lesson1/voice_lines.csv"), encoding: .utf8)
        let ids = csv.split(separator: "\n").dropFirst().compactMap { $0.split(separator: ",").first.map(String.init) }
        #expect(ids.count > 100)
        for id in ids {
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(id).m4a").path), "no recording for \(id)")
        }
    }

    @Test func breakVoiceLinesExist() throws {
        let voice = try ContentFiles.voice
        for key in ["l1_br_start", "l1_br_move", "l1_br_breathe", "l1_br_quiet", "l1_br_end"] {
            #expect(voice[key] != nil, "missing \(key)")
        }
    }
}

@Suite("Film clips and subtitles")
struct FilmTests {
    /// rokko/Resources/Video, next to rokko/Content.
    static let video = ContentFiles.root.deletingLastPathComponent().appendingPathComponent("Resources/Video")
    static let subtitles = ContentFiles.root.appendingPathComponent("Lesson1/Subtitles")

    static var filmClips: [ClipManifest.Clip] {
        get throws {
            let manifest = try LessonStepTests.manifest
            return try LessonStepTests.lesson.steps.filter { $0.kind == .film }.compactMap { $0.clip.flatMap(manifest.clip) }
        }
    }

    @Test func theFilmIsEightClipsInOrder() throws {
        let ids = try Self.filmClips.map(\.id)
        #expect(ids == ["L1_01_story", "L1_02_kings", "L1_03_queens", "L1_04_elephants",
                        "L1_05_kangaroos", "L1_06_horses", "L1_07_squirrels", "L1_08_ending"])
        for step in try LessonStepTests.lesson.steps where step.kind == .film {
            #expect(step.again, "\(step.id): film clips can be replayed")
        }
    }

    /// A missing asset fails here, not at runtime.
    @Test func everyFilmClipFileIsDelivered() throws {
        for clip in try Self.filmClips {
            for file in Set(clip.files.values) {
                #expect(FileManager.default.fileExists(atPath: Self.video.appendingPathComponent(file).path),
                        "\(clip.id): missing Resources/Video/\(file)")
            }
            #expect((clip.seconds ?? 0) > 0, "\(clip.id): needs its length in seconds")
            let still = try #require(clip.endStill, "\(clip.id): no endStill (run Tools/subtitle_speech_spans.py)")
            #expect(still > 0 && still < (clip.seconds ?? 0), "\(clip.id): endStill outside the clip")
        }
    }

    /// The six animal → piece clips (Tools/make_transform_clips.py), Calm and Standard (docs/ASSETS.md › Video).
    @Test func everyTransformationClipIsDelivered() throws {
        let manifest = try LessonStepTests.manifest
        let clips = try LessonStepTests.lesson.steps.filter { $0.kind == .transform }.compactMap { $0.clip.flatMap(manifest.clip) }
        #expect(clips.count == 6)
        for clip in clips {
            for version in ["calm", "standard"] {
                let file = try #require(clip.files[version], "\(clip.id): no \(version) file")
                #expect(FileManager.default.fileExists(atPath: Self.video.appendingPathComponent(file).path),
                        "\(clip.id): missing Resources/Video/\(file)")
            }
            let still = try #require(clip.endStill, "\(clip.id): no endStill")
            #expect(still > 0 && still < (clip.seconds ?? 0), "\(clip.id): endStill outside the clip")
        }
    }

    @Test func everyFilmClipHasValidSubtitles() throws {
        let banned = ["amazon", "wrong", "fail", "mistake"]
        for clip in try Self.filmClips {
            let file = try #require(clip.subtitles, "\(clip.id): no subtitles file in manifest.json")
            let subs = try Subtitles.load(from: Self.subtitles.appendingPathComponent(file))
            #expect(subs.clip == clip.id, "\(file): clip id should be \(clip.id)")
            #expect(!subs.cues.isEmpty, "\(file): no cues")
            var previousEnd = 0.0
            for cue in subs.cues {
                #expect(cue.start < cue.end, "\(file): \"\(cue.text)\" ends before it starts")
                #expect(cue.start >= previousEnd, "\(file): \"\(cue.text)\" overlaps the line before")
                #expect(cue.end <= (clip.seconds ?? 0), "\(file): \"\(cue.text)\" runs past the end of the clip")
                #expect(!cue.text.trimmingCharacters(in: .whitespaces).isEmpty, "\(file): empty cue")
                #expect(!cue.speech.isEmpty, "\(file): \"\(cue.text)\" has no speech timing (run Tools/subtitle_speech_spans.py)")
                var spanEnd = cue.start
                for span in cue.speech {
                    #expect(span.count == 2 && span[0] >= spanEnd && span[0] < span[1] && span[1] <= cue.end + 0.05,
                            "\(file): bad speech span \(span) in \"\(cue.text)\"")
                    spanEnd = span.last ?? spanEnd
                }
                for word in banned { #expect(!cue.text.lowercased().contains(word), "\(file): uses \"\(word)\"") }
                previousEnd = cue.end
            }
        }
    }

    @Test func timesParse() {
        #expect(Subtitles.parseTime("00:04.800") == 4.8)
        #expect(Subtitles.parseTime("01:09.354") == 69.354)
        #expect(Subtitles.parseTime("00:04,800") == 4.8)
        #expect(Subtitles.parseTime("1:00:00.000") == 3600)
        #expect(Subtitles.parseTime("00:60.000") == nil)
        #expect(Subtitles.parseTime("4.8") == nil)
    }

    @Test func oneCueAtATime() {
        let subs = Subtitles(clip: "x", cues: [.init(start: 1, end: 2, text: "a"), .init(start: 3, end: 4, text: "b")])
        #expect(subs.cue(at: 0.5) == nil)
        #expect(subs.cue(at: 1)?.text == "a")
        #expect(subs.cue(at: 2) == nil)
        #expect(subs.cue(at: 3.5)?.text == "b")
        #expect(subs.cue(at: 4) == nil)
    }

    @Test func wordsAppearAsTheyAreSaid() {
        // Two words over two stretches of speech with a pause between them.
        let cue = Subtitles.Cue(start: 0, end: 4, text: "Hello there", speech: [[0, 1], [3, 4]])
        #expect(cue.shownCharacters(at: 0) == 5)       // "Hello" as the voice starts
        #expect(cue.shownCharacters(at: 1.5) == 5)     // pause: nothing new
        #expect(cue.shownCharacters(at: 2.5) == 5)
        #expect(cue.shownCharacters(at: 3.2) == 11)    // "there" once the voice reaches it
        #expect(cue.shownCharacters(at: 4) == 11)
    }

    @Test func speakerTagShowsAtOnce() {
        let cue = Subtitles.Cue(start: 10, end: 12, text: "Horse: \"I jump far!\"", speech: [[10, 12]])
        #expect(cue.speakerTagLength == 8)             // Horse: "
        #expect(cue.shownCharacters(at: 10) == 9)      // Horse: "I
        #expect(cue.shownCharacters(at: 12) == cue.text.count)
        #expect(Subtitles.Cue(start: 0, end: 1, text: "No tag here.").speakerTagLength == 0)
    }
}
