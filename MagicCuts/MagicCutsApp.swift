//
//  MagicCutsApp.swift
//  MagicCuts
//
//  Created by Bradley Zellman on 10/5/25.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct MagicCutsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MonitoredDevice.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema, 
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.com.bradzellman.magiccuts")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
