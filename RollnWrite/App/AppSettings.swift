//
//  AppSettings.swift
//  RollnWrite – App
//
//  App-wide preferences. Currently the appearance (Light / Dark / System), which
//  the user picks in Settings and which is applied at the app root via
//  `.preferredColorScheme`. Light mode gives the board a white page so the
//  coloured bands read like the official printed card; dark mode keeps the
//  modern edge-to-edge look. Persisted with `@AppStorage`.
//

import SwiftUI

/// The user's chosen appearance. Stored as its raw `String` in `@AppStorage`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// `nil` means "follow the system" — what `.preferredColorScheme` expects.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    static let storageKey = "appearance"
}

/// Settings sheet — presented from the catalogue.
struct SettingsView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.dismiss) private var dismiss

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("App", value: "Roll'n Write")
                    LabeledContent("Build", value: versionString)
                } footer: {
                    Text("A scorecard for roll-and-write dice games. No accounts, no tracking.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
