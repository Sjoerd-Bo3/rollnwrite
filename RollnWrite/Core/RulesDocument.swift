//
//  RulesDocument.swift
//  RollnWrite – Core
//
//  A presentation-agnostic model for a game's rules, plus a generic renderer.
//
//  SRP: rules *content* (this model) is separated from rules *presentation*
//  (`RulesView`). A new game supplies a `RulesDocument`; it never writes rules UI.
//

import SwiftUI

/// A single titled block of rules text.
public struct RulesSection: Identifiable {
    public let id = UUID()
    public let heading: String
    /// Each entry is rendered as its own paragraph / bullet.
    public let body: [String]

    public init(heading: String, body: [String]) {
        self.heading = heading
        self.body = body
    }
}

/// Structured, official rules for a game variant.
public struct RulesDocument {
    public let title: String
    public let subtitle: String
    public let sections: [RulesSection]
    /// Attribution so we always credit the official rules/scorecard source.
    public let source: String
    /// Optional link to the publisher's official rules. Opened in the system
    /// browser, so we *link* to their PDF rather than redistribute the
    /// copyrighted file.
    public let officialRulesURL: URL?

    public init(title: String, subtitle: String, sections: [RulesSection],
                source: String, officialRulesURL: URL? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.sections = sections
        self.source = source
        self.officialRulesURL = officialRulesURL
    }
}

/// Generic renderer for any `RulesDocument`. Reused by every game.
public struct RulesView: View {
    public let document: RulesDocument
    @Environment(\.dismiss) private var dismiss

    public init(document: RulesDocument) {
        self.document = document
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.title)
                            .font(.title2.bold())
                        Text(document.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.heading)
                                .font(.headline)
                            ForEach(Array(section.body.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•").foregroundStyle(.secondary)
                                    Text(line)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .font(.callout)
                            }
                        }
                    }

                    Divider()
                    Text("Source: \(document.source)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let url = document.officialRulesURL {
                        Link(destination: url) {
                            Label("Official rules (PDF)", systemImage: "doc.text")
                                .font(.callout.weight(.semibold))
                        }
                        .padding(.top, 2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
