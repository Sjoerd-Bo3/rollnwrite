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

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
