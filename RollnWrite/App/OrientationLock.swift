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
            .onAppear {
                OrientationGate.mask = mask
                guard let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
                // Nudge the system to re-evaluate now (so it rotates immediately,
                // not just on the next physical turn).
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            .onDisappear {
                // Hand rotation freedom back to whatever comes next (the menu).
                OrientationGate.mask = .all
            }
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
