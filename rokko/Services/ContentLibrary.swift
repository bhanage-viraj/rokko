//
//  ContentLibrary.swift
//  Loads the bundled content once: lesson steps, clip manifest, exercise pool, engine config, voice lines.
//  A missing or broken file is reported (ContentValidationTests catch it first), never a crash.
//

import Foundation
import RokkoContent
import RokkoEngine

@MainActor
final class ContentLibrary {
    static let shared: Result<ContentLibrary, ContentError> = {
        do { return .success(try ContentLibrary(bundle: .main)) }
        catch let e as ContentError { return .failure(e) }
        catch { return .failure(.unreadable("content", error.localizedDescription)) }
    }()

    let lesson: Lesson
    let manifest: ClipManifest
    let pool: ExercisePool
    let config: EngineConfig
    let voice: VoiceLines
    let generator: RoundGenerator

    init(bundle: Bundle) throws {
        func url(_ name: String, _ ext: String) throws -> URL {
            guard let u = bundle.url(forResource: name, withExtension: ext) else { throw ContentError.missing("\(name).\(ext)") }
            return u
        }
        do {
            lesson = try Lesson.load(from: url("lesson1", "json"))
            manifest = try ClipManifest.load(from: url("manifest", "json"))
            pool = try ExercisePool.load(from: url("exercise_pool", "json"))
            config = try EngineConfig.load(from: url("EngineConfig", "json"))
            voice = try VoiceLines.load(from: url("voice_lines", "csv"))
        } catch let e as ContentError {
            throw e
        } catch {
            throw ContentError.unreadable("content", String(describing: error))
        }
        generator = RoundGenerator(settings: .init(config))
        planner = RoundPlanner(config: config, pool: pool)
    }

    let planner: RoundPlanner

    /// The clip file for this look, if the video team has delivered it (nil = the slot stays blank).
    func clipURL(_ id: String, calm: Bool) -> URL? {
        guard let file = manifest.clip(id)?.files[calm ? "calm" : "standard"] else { return nil }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    /// Subtitles of a film clip (Content/Lesson1/Subtitles/), loaded once. Nil = the clip has none.
    func subtitles(for clipId: String) -> Subtitles? {
        if let cached = subtitleCache[clipId] { return cached }
        guard let file = manifest.clip(clipId)?.subtitles else { return nil }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let subs = try? Subtitles.load(from: url) else { return nil }   // ContentValidationTests catch this first
        subtitleCache[clipId] = subs
        return subs
    }

    private var subtitleCache: [String: Subtitles] = [:]

    /// Caption for a voice key: always the recorded line's exact text.
    func caption(_ key: String) -> String? { voice[key]?.text }
}

enum ContentError: Error, CustomStringConvertible {
    case missing(String)
    case unreadable(String, String)

    var description: String {
        switch self {
        case .missing(let f): "Missing content file: \(f)"
        case .unreadable(let f, let why): "Could not read \(f): \(why)"
        }
    }
}
