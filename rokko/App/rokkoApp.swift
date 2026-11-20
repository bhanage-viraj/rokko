//
//  rokkoApp.swift
//  rokko
//
//  Created by Viraj Bhanage on 12/11/26.
//

import SwiftUI
import SwiftData

@main
struct rokkoApp: App {
    var body: some Scene {
        WindowGroup {
            RokkoRoot()
        }
        .modelContainer(for: Store.models, inMemory: Self.isUITesting)
    }

    /// UI tests launch with `-RokkoUITesting YES`: SwiftData then lives in memory only, so every
    /// test starts like a fresh install and never touches the real child profile.
    static var isUITesting: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "RokkoUITesting")
        #else
        false
        #endif
    }
}
