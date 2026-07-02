//
//  Feedback.swift
//  RollnWrite – App
//
//  In-app bug reports & feature requests that funnel into GitHub issues
//  without a backend and without embedding a token (anything shipped in the
//  binary is extractable). Instead the user composes the report here and we
//  open GitHub's "new issue" page with `title`, `body` and `labels` pre-filled
//  as percent-encoded query parameters — Safari (or the GitHub app) shows the
//  form fully filled in and the user just taps Submit. A GitHub account is
//  required to submit; that is inherent to the no-backend approach and is
//  stated in the UI footer.
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

    /// The GitHub label pre-applied to the created issue.
    var gitHubLabel: String {
        switch self {
        case .bug:     return "bug"
        case .feature: return "enhancement"
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

// MARK: - URL builder

/// Builds GitHub "new issue" URLs with the report pre-filled.
///
/// Values are strictly percent-encoded (everything outside RFC 3986
/// "unreserved" is escaped) so `&`, `#`, `+`, `=`, newlines and emoji all
/// survive: `URLQueryItem`'s default encoding leaves `+` bare, which GitHub —
/// like most form decoders — would turn into a space.
enum GitHubIssueURL {
    static let repository = "Sjoerd-Bo3/rollnwrite"

    /// Practical cap well below browser/server URL limits; longer bodies are
    /// truncated with an ellipsis note.
    static let maxURLLength = 6000

    private static let truncationNote = "\n\n…\n\n_(Description truncated — it was too long to fit in a pre-filled link.)_"

    /// The pre-filled new-issue URL, truncating the body if the total URL
    /// would exceed `maxURLLength`.
    static func newIssue(title: String, body: String, labels: [String]) -> URL? {
        guard let url = build(title: title, body: body, labels: labels) else { return nil }
        guard url.absoluteString.count > maxURLLength else { return url }

        // Too long — shrink the body geometrically until the URL fits.
        // (Grapheme-safe: `prefix` never splits a character, so emoji stay intact.)
        var kept = body
        while !kept.isEmpty {
            kept = String(kept.prefix(kept.count * 3 / 4))
            if let shorter = build(title: title, body: kept + truncationNote, labels: labels),
               shorter.absoluteString.count <= maxURLLength {
                return shorter
            }
        }
        return build(title: title, body: truncationNote, labels: labels)
    }

    private static func build(title: String, body: String, labels: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/\(repository)/issues/new"
        // `percentEncodedQueryItems` takes pre-encoded values verbatim; the
        // plain `queryItems` setter would re-encode too loosely (see above).
        components.percentEncodedQueryItems = [
            ("title", title),
            ("labels", labels.joined(separator: ",")),
            ("body", body),
        ].map { URLQueryItem(name: $0.0, value: strictlyEncoded($0.1)) }
        return components.url
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
                        Label("Open GitHub", systemImage: "arrow.up.forward.app")
                    }
                    .disabled(trimmedTitle.isEmpty)
                } footer: {
                    Text("Opens GitHub with your report pre-filled — a GitHub account is needed to submit.")
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
        guard let url = GitHubIssueURL.newIssue(
            title: trimmedTitle,
            body: issueBody,
            labels: [kind.gitHubLabel]
        ) else { return }
        openURL(url)
        dismiss()
    }
}
