//
//  OrientationLock.swift
//  RollnWrite – App
//
//  Per-screen orientation control. The catalogue (menu) is free to rotate, but
//  individual scorecards can pin themselves to landscape. iOS has no SwiftUI API
//  for this, so a tiny UIApplicationDelegate reports the current allowed mask and
//  views update it as they appear/disappear.
//

import SwiftUI

/// Shared, app-wide orientation mask consulted by the app delegate.
enum OrientationGate {
    /// Default: let the device decide (used by the catalogue).
    static var mask: UIInterfaceOrientationMask = .all
}

/// Reports `OrientationGate.mask` to UIKit. Wired up via `@UIApplicationDelegateAdaptor`.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationGate.mask
    }
}

private struct LockOrientation: ViewModifier {
    let mask: UIInterfaceOrientationMask

    func body(content: Content) -> some View {
        content
            .onAppear { Self.apply(mask) }
            // The mask can change while the screen is visible (e.g. the
            // two-player toggle flips the lock off). `onAppear` only fires
            // once, so re-apply whenever it changes.
            .onChange(of: mask.rawValue) { Self.apply(mask) }
            .onDisappear {
                // Hand rotation freedom back to whatever comes next (the
                // menu). Must prod the system too: iOS 16+ caches supported
                // orientations, so just resetting the gate leaves the app
                // stuck in landscape until the next lock.
                Self.apply(.all)
            }
    }

    /// Set the app-wide gate and prod UIKit to re-evaluate immediately —
    /// `requestGeometryUpdate` snaps the interface to an allowed orientation
    /// (e.g. back to portrait when the phone is upright) and
    /// `setNeedsUpdateOfSupportedInterfaceOrientations` makes the system
    /// re-read the delegate's mask instead of its cached copy.
    static func apply(_ mask: UIInterfaceOrientationMask) {
        OrientationGate.mask = mask
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

extension View {
    /// Pin this screen to landscape on iPhone; iPad keeps every orientation so
    /// the mirrored two-player layout still works in portrait.
    func landscapeLockediPhone() -> some View {
        let phone = UIDevice.current.userInterfaceIdiom == .phone
        return modifier(LockOrientation(mask: phone ? .landscape : .all))
    }

    /// Pin to landscape only while `active` is true (e.g. single-player); when
    /// false the screen may rotate freely (e.g. portrait two-player on iPhone).
    func landscapeLockediPhone(when active: Bool) -> some View {
        let phone = UIDevice.current.userInterfaceIdiom == .phone
        return modifier(LockOrientation(mask: (phone && active) ? .landscape : .all))
    }
}
