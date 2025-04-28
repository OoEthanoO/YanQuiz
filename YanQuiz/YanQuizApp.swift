//
//  YanQuizApp.swift
//  YanQuiz
//
//  Created by Ethan Xu on 2025-04-19.
//

import SwiftUI
import SwiftData

@main
struct YanQuizApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Quiz.self,
            Question.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
