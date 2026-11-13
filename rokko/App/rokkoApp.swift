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
        .modelContainer(for: Store.models)
    }
}
