// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Decides when a Control shortcut should reach the app as the matching
/// Command shortcut (Ctrl+A/C/V/X/Z becomes ⌘A/⌘C/⌘V/⌘X/⌘Z). Pure logic with no
/// event tap, so it can be tested on its own.
///
/// Only the flags of the original event are rewritten; nothing is posted, so
/// key repeat, key-up pairing and event ordering stay untouched.
enum CtrlShortcutsSupport {
    /// ANSI virtual key codes for the shortcuts that get remapped.
    static let selectAllKey: Int64 = 0
    static let copyKey: Int64 = 8
    static let pasteKey: Int64 = 9
    static let cutKey: Int64 = 7
    static let undoKey: Int64 = 6
    static let remappedKeys: Set<Int64> = [selectAllKey, copyKey, pasteKey, cutKey, undoKey]

    /// Terminals use Ctrl+C/Z/A for signals and line editing, so they start
    /// excluded. The user can edit the list.
    static let defaultExcludedBundleIDs: [String] = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
    ]

    static func decodeExcluded(_ raw: String) -> Set<String> {
        Set(raw.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    static func encodeExcluded(_ ids: [String]) -> String {
        var seen = Set<String>()
        return ids.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: ",")
    }

    /// The flags to use instead of `flags`, or nil to leave the event alone.
    /// Only a Control press that carries no Command or Option is rewritten, so
    /// ⌘C, ⌃⌘C and ⌥⌃C keep their meaning. Shift is preserved (⌃⇧Z → ⌘⇧Z).
    static func rewrittenFlags(keyCode: Int64,
                               flags: CGEventFlags,
                               frontmostBundleID: String?,
                               excludedBundleIDs: Set<String>) -> CGEventFlags? {
        guard remappedKeys.contains(keyCode),
              flags.contains(.maskControl),
              !flags.contains(.maskCommand),
              !flags.contains(.maskAlternate) else { return nil }
        if let frontmostBundleID, excludedBundleIDs.contains(frontmostBundleID) { return nil }
        var result = flags
        result.remove(.maskControl)
        result.insert(.maskCommand)
        return result
    }
}
