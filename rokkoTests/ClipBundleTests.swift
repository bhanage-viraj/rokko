//
//  ClipBundleTests.swift
//  Every clip lesson1.json plays is in the built app: ContentLibrary.clipURL finds the Calm and the
//  Standard file of each one in Bundle.main (rokko/Resources/Video, a synchronized group).
//  A missing video fails here, never as a blank slot at runtime.
//

import Foundation
import Testing
import RokkoContent
@testable import rokko

@MainActor
struct ClipBundleTests {
    let library: ContentLibrary

    init() throws {
        library = try ContentLibrary(bundle: .main)
    }

    @Test func everyLessonClipIsInTheAppBundle() throws {
        let ids = Set(library.lesson.steps.filter { $0.kind == .film || $0.kind == .transform }.compactMap(\.clip))
        var files = Set<String>()
        for id in ids {
            let clip = try #require(library.manifest.clip(id), "\(id): not in manifest.json")
            for calm in [true, false] {
                let url = try #require(library.clipURL(id, calm: calm), "\(id): \(calm ? "calm" : "standard") file not in the app bundle")
                #expect(FileManager.default.isReadableFile(atPath: url.path), "\(url.lastPathComponent) unreadable")
                files.insert(url.lastPathComponent)
            }
            #expect(Set(clip.files.values).isSubset(of: files), "\(id)")
        }
        // 8 film clips (one file serves both looks) + 6 transformations × (calm, standard).
        #expect(files.count == 20, "found \(files.sorted())")
    }

    @Test func transformationsHaveADistinctCalmFile() throws {
        for step in library.lesson.steps where step.kind == .transform {
            let id = try #require(step.clip, "\(step.id): no clip")
            let calm = try #require(library.clipURL(id, calm: true))
            let standard = try #require(library.clipURL(id, calm: false))
            #expect(calm != standard, "\(id): Calm must get the plain cross-fade, not the standard clip")
            #expect(calm.lastPathComponent.hasSuffix("_calm.mp4"), "\(id)")
        }
    }
}
