// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Decides when a Control shortcut should reach the app as the matching
/// Command shortcut (Ctrl+A/C/V/X/Z/S becomes ⌘A/⌘C/⌘V/⌘X/⌘Z/⌘S). Pure logic with no
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
    static let saveKey: Int64 = 1
    static let remappedKeys: Set<Int64> = [selectAllKey, copyKey, pasteKey, cutKey, undoKey, saveKey]

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
        result.remove(CGEventFlags(rawValue: leftControlDeviceBit | rightControlDeviceBit))
        result.insert(.maskCommand)
        result.insert(CGEventFlags(rawValue: leftCommandDeviceBit))
        return result
    }

    // Device-dependent modifier bits (IOKit NX_DEVICE*KEYMASK). They say which
    // side was pressed; a Command shortcut must not keep a Control side bit.
    static let leftControlDeviceBit: UInt64 = 0x0000_0001
    static let rightControlDeviceBit: UInt64 = 0x0000_2000
    static let leftCommandDeviceBit: UInt64 = 0x0000_0008

    static let leftControlKeyCode: CGKeyCode = 59
    static let rightControlKeyCode: CGKeyCode = 62
    static let leftCommandKeyCode: CGKeyCode = 55

    /// The Control key that is physically held, so the replay releases and
    /// restores the same one (external keyboards like Keychron have both).
    static func heldControlKeyCode(_ flags: CGEventFlags) -> CGKeyCode {
        let raw = flags.rawValue
        if raw & rightControlDeviceBit != 0 && raw & leftControlDeviceBit == 0 {
            return rightControlKeyCode
        }
        return leftControlKeyCode
    }

    /// Flags for the Control key-down that is restored after the replay.
    static func controlRestoreFlags(base: CGEventFlags, controlKey: CGKeyCode) -> CGEventFlags {
        let side = controlKey == rightControlKeyCode ? rightControlDeviceBit : leftControlDeviceBit
        return base.union(.maskControl).union(CGEventFlags(rawValue: side))
    }

    /// Flags with every Control and Command bit removed (side bits included).
    static func withoutControlOrCommand(_ flags: CGEventFlags) -> CGEventFlags {
        flags.subtracting([.maskControl, .maskCommand])
            .subtracting(CGEventFlags(rawValue: leftControlDeviceBit | rightControlDeviceBit
                                      | leftCommandDeviceBit | 0x0000_0010))
    }
}
