//
//  RollnWriteApp.swift
//  RollnWrite
//
//  App entry point. Intentionally tiny — composition only.
//

import SwiftUI

@main
struct RollnWriteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                // Apply the chosen appearance to the whole window. `nil` follows
                // the system. Light mode gives the boards a white page to match
                // the official cards.
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
        }
    }
}
