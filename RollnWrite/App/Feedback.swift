//
//  Feedback.swift
//  RollnWrite – App
//
//  In-app bug reports & feature requests, backend-free. The user composes the
//  report here and we open a `mailto:` link with the subject and body
//  pre-filled as percent-encoded query parameters — the system Mail app opens
//  ready to send. No account beyond the mail app the user already has.
//

import SwiftUI
import UIKit

// MARK: - Kind

/// What the user is filing. Maps onto the repository's issue labels.
enum FeedbackKind: String, CaseIterable, Identifiable {
    case bug, feature

    var id: String { rawValue }

    /// Segment title in the composer's kind picker.
    var label: LocalizedStringKey {
        switch self {
        case .bug:     return "Bug report"
        case .feature: return "Feature request"
        }
    }

    /// Navigation title of the composer sheet.
    var composerTitle: LocalizedStringKey {
        switch self {
        case .bug:     return "Report a bug"
        case .feature: return "Request a feature"
        }
    }

    /// Prefix for the email subject, so reports are easy to spot and filter.
    var subjectPrefix: String {
        switch self {
        case .bug:     return "Bug"
        case .feature: return "Feature request"
        }
    }
}

// MARK: - Device info

/// Builds the small diagnostics block appended under the description of a
/// report (when the user leaves "Include device info" on). Deliberately tiny
/// and fully visible in the composer — no hidden data leaves the device.
@MainActor
enum FeedbackDeviceInfo {
    /// The exact markdown appended to the issue body: a `---` separator
    /// followed by a two-column table.
    static var markdownBlock: String {
        let rows: [(String, String)] = [
            ("App", appVersion),
            ("iOS", UIDevice.current.systemVersion),
            ("Device", modelIdentifier),
            ("Appearance", appearance),
            ("Locale", Locale.current.identifier),
        ]
        return "---\n\n| | |\n|---|---|\n"
            + rows.map { "| \($0.0) | \($0.1) |" }.joined(separator: "\n")
    }

    /// Marketing version + build, e.g. "1.2 (34)".
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// The hardware model identifier (e.g. "iPhone15,3"), which — unlike
    /// `UIDevice.model` — distinguishes actual devices.
    private static var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    /// The app's appearance setting ("system" / "light" / "dark").
    private static var appearance: String {
        UserDefaults.standard.string(forKey: AppearanceMode.storageKey)
            ?? AppearanceMode.system.rawValue
    }
}

// MARK: - Mail URL builder

/// Builds a `mailto:` URL with the report pre-filled into the subject and body,
/// so the user's Mail app opens ready to send.
///
/// Values are strictly percent-encoded (everything outside RFC 3986
/// "unreserved" is escaped) so `&`, `#`, `+`, `=`, newlines and emoji all
/// survive — space becomes `%20`, not `+`, which some mail clients would leave
/// literal.
enum FeedbackMailURL {
    static let recipient = "sjoerd.bozon@gmail.com"

    /// Practical cap: some mail clients truncate very long `mailto:` links, so
    /// the body is shrunk to fit.
    static let maxURLLength = 2000

    private static let truncationNote = "\n\n…\n\n(Description truncated — it was too long to fit in a pre-filled link.)"

    /// The pre-filled `mailto:` URL, truncating the body if the total URL would
    /// exceed `maxURLLength`.
    static func compose(subject: String, body: String) -> URL? {
        guard let url = build(subject: subject, body: body) else { return nil }
        guard url.absoluteString.count > maxURLLength else { return url }

        // Too long — shrink the body geometrically until the URL fits.
        // (Grapheme-safe: `prefix` never splits a character, so emoji stay intact.)
        var kept = body
        while !kept.isEmpty {
            kept = String(kept.prefix(kept.count * 3 / 4))
            if let shorter = build(subject: subject, body: kept + truncationNote),
               shorter.absoluteString.count <= maxURLLength {
                return shorter
            }
        }
        return build(subject: subject, body: truncationNote)
    }

    private static func build(subject: String, body: String) -> URL? {
        URL(string: "mailto:\(recipient)?subject=\(strictlyEncoded(subject))&body=\(strictlyEncoded(body))")
    }

    private static func strictlyEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) ?? value
    }
}

private extension CharacterSet {
    /// RFC 3986 §2.3 "unreserved" — the only characters safe to leave bare in
    /// any URL component.
    static let rfc3986Unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
}

// MARK: - Composer

/// The feedback sheet: pick bug/feature, write a title and description,
/// optionally attach the device-info block, then hand off to GitHub.
struct FeedbackComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var kind: FeedbackKind
    @State private var title = ""
    @State private var details = ""
    @State private var includeDeviceInfo = true

    init(kind: FeedbackKind) {
        _kind = State(initialValue: kind)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Description plus (optionally) the device-info block under a `---` rule.
    private var issueBody: String {
        var parts: [String] = []
        let description = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { parts.append(description) }
        if includeDeviceInfo { parts.append(FeedbackDeviceInfo.markdownBlock) }
        return parts.joined(separator: "\n\n")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(FeedbackKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Title") {
                    TextField("Short summary", text: $title)
                }

                Section("Description") {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)
                }

                Section {
                    Toggle("Include device info", isOn: $includeDeviceInfo)
                    if includeDeviceInfo {
                        // Show the *exact* text that will be appended.
                        Text(FeedbackDeviceInfo.markdownBlock)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button(action: submit) {
                        Label("Compose email", systemImage: "envelope")
                    }
                    .disabled(trimmedTitle.isEmpty)
                } footer: {
                    Text("Opens your Mail app with your report pre-filled.")
                }
            }
            .navigationTitle(kind.composerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() {
        guard let url = FeedbackMailURL.compose(
            subject: "\(kind.subjectPrefix): \(trimmedTitle)",
            body: issueBody
        ) else { return }
        openURL(url)
        dismiss()
    }
}
