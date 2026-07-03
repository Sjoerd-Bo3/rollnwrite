//
//  AppSettings.swift
//  RollnWrite – App
//
//  App-wide preferences: the appearance (Light / Dark / System), applied at the
//  app root via `.preferredColorScheme`, and the dice colours — the player's
//  physical dice set (`DiceTheme`), which every Clever board maps its areas
//  onto. Light mode gives the board a white page so the coloured bands read
//  like the official printed card; dark mode keeps the modern edge-to-edge
//  look. Appearance is persisted with `@AppStorage`; the dice palette persists
//  itself (see `DiceTheme`).
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
    @ObservedObject private var diceTheme = DiceTheme.shared
    @Environment(\.dismiss) private var dismiss
    @State private var scores: [(name: String, best: Int)] = []
    @State private var feedbackKind: FeedbackKind?
    @State private var showDiceScan = false

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    /// A `ColorPicker` binding onto one dice-palette slot.
    private func dieColor(_ slot: Int) -> Binding<Color> {
        Binding(
            get: { diceTheme.palette[slot].color },
            set: { diceTheme.palette[slot] = RGBAColor($0) }
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

                // Dice colours drive the Clever areas; the Qwixx-only App
                // Store cut ships nothing that uses them, so hide the section.
                #if !QWIXX_ONLY
                Section {
                    ForEach(0..<DiceTheme.slotCount, id: \.self) { i in
                        ColorPicker("Die \(i + 1)", selection: dieColor(i), supportsOpacity: false)
                    }
                    Button {
                        showDiceScan = true
                    } label: {
                        Label("Scan dice", systemImage: "camera.viewfinder")
                    }
                    Button("Reset to standard colours") { diceTheme.resetToDefault() }
                } header: {
                    Text("Dice colours")
                } footer: {
                    Text("Set the colours of your physical dice once; every game shows each of its areas in the nearest of your dice colours. Scoring is unchanged.")
                }
                #endif

                if !scores.isEmpty {
                    Section("High scores") {
                        ForEach(scores, id: \.name) { entry in
                            LabeledContent(entry.name, value: "\(entry.best)")
                        }
                        Button("Reset high scores", role: .destructive) {
                            HighScores.reset()
                            scores = []
                        }
                    }
                }

                Section {
                    Button {
                        feedbackKind = .bug
                    } label: {
                        Label("Report a bug", systemImage: "ladybug")
                    }
                    Button {
                        feedbackKind = .feature
                    } label: {
                        Label("Request a feature", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Opens GitHub with your report pre-filled — a GitHub account is needed to submit.")
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
            .onAppear { scores = HighScores.all() }
            .sheet(item: $feedbackKind) { kind in
                FeedbackComposerView(kind: kind)
            }
            .sheet(isPresented: $showDiceScan) {
                DiceScanView()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
