//
//  CleverEngine.swift
//  RollnWrite – Clever (shared engine behaviour)
//
//  DIP/ISP: the Clever engines share lifecycle machinery. Rather than copy it
//  per game, that shared behaviour lives here as small, focused protocols with
//  default implementations; each engine conforms and supplies only its own
//  specifics (its `Action` type, the raw per-action state mutations, and its
//  fox-count derivation). "Roll out to another Clever" = conform, not paste.
//

import SwiftUI

// MARK: - Undo / redo (LIFO history + in-memory redo stack)

/// The shared undo/redo bookkeeping for a Clever engine. The engine stores its
/// LIFO `history` inside its `Codable` state and keeps an in-memory `redoStack`
/// (a per-session convenience, never persisted); this protocol supplies the
/// identical record / undo / redo logic once. The engine provides only the raw
/// per-`Action` state mutations (`reverse` for undo, `replay` for redo) and the
/// `history` accessor onto its own state. Persistence stays the engine's job:
/// the helpers return whether they changed anything so the engine can `save()`.
@MainActor
protocol CleverUndoRedo: AnyObject {
    associatedtype Action

    /// The persisted LIFO history — backed by the engine's `state.history`.
    var history: [Action] { get set }
    /// In-memory, per-session redo stack. NOT persisted.
    var redoStack: [Action] { get set }
    /// True only while `performRedo()` is replaying, so `recordAction` does not
    /// treat that replay as a fresh forward move (which would clear the stack).
    var isRedoing: Bool { get set }

    /// Undo the RAW state mutation for `action` (no bonus chaining).
    func reverse(_ action: Action)
    /// Re-apply the RAW state mutation for `action` (no bonus chaining).
    func replay(_ action: Action)
}

extension CleverUndoRedo {
    var undoAvailable: Bool { !history.isEmpty }
    var redoAvailable: Bool { !redoStack.isEmpty }

    /// Append a forward move to the history. Any forward move — i.e. every call
    /// site except `performRedo()` replaying an undone one — invalidates the
    /// redo stack (standard editor semantics).
    func recordAction(_ action: Action) {
        history.append(action)
        if !isRedoing { redoStack = [] }
    }

    /// Pop + reverse the most recent action, pushing it to the redo stack.
    /// Returns `true` if something was undone (so the engine can persist).
    func performUndo() -> Bool {
        guard let last = history.popLast() else { return false }
        reverse(last)
        redoStack.append(last)
        return true
    }

    /// Pop + replay the most recently undone action. Returns `true` if something
    /// was redone (so the engine can persist). Replays the RAW mutation only —
    /// never the public mutators — so `applyNewlyEarned` bonus chains that are
    /// already on the card are not re-fired.
    func performRedo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        isRedoing = true
        replay(next)
        recordAction(next)
        isRedoing = false
        return true
    }
}

// MARK: - Fox scoring

/// Fox scoring shared by the Clever engines: each fox is worth the lowest single
/// area score. The engine supplies `foxCount` (derived from state in Clever 1,
/// a manual stepper count in Clever 2) and `lowestAreaScore`; the product is the
/// same everywhere.
@MainActor
protocol CleverFoxScoring: AnyObject {
    var foxCount: Int { get }
    var lowestAreaScore: Int { get }
}

extension CleverFoxScoring {
    var foxScore: Int { foxCount * lowestAreaScore }
}
