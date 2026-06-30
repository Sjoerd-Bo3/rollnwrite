//
//  KeepScreenAwake.swift
//  RollnWrite – Core
//
//  Keeps the display awake while a scorecard is on screen, so the board never
//  dims or auto-locks mid-game (you're tapping intermittently, not continuously,
//  so iOS would otherwise sleep the screen). Restores normal behaviour on exit.
//

import SwiftUI

public extension View {
    /// Disables the screen auto-lock while this view is visible.
    func keepsScreenAwake() -> some View {
        modifier(KeepScreenAwakeModifier())
    }
}

private struct KeepScreenAwakeModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #else
        content
        #endif
    }
}
