// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// Decides when a Control shortcut should reach the app as the matching Command
/// shortcut (Ctrl+A/C/V/X/Z/S becomes ⌘A/⌘C/⌘V/⌘X/⌘Z/⌘S) and, for apps the user lists,
/// when a Command shortcut should reach the app as the Control one (⌘C becomes Ctrl+C,
/// so it can interrupt a command in a terminal that lives inside an editor or a chat app).
/// Pure logic with no event tap, so it can be tested on its own. The tap that posts the
/// events is in `CtrlShortcutsService`, driven by `CtrlReplayEngine`.
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

    /// A terminal inside a bigger app (an editor, a chat) cannot be excluded with the whole app:
    /// the same app wants Ctrl+C to copy. There, Command+C is sent as Ctrl+C, so it interrupts.
    static let defaultCommandAsControl = "com.anthropic.claudefordesktop:c;com.microsoft.VSCode:c"

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

    // MARK: - Command sent as Control (per app)

    /// ANSI key codes of the letters, for the "Command sent as Control" setting.
    static let keyCodeByLetter: [Character: Int64] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37,
        "j": 38, "k": 40, "n": 45, "m": 46,
    ]
    static let letterByKeyCode: [Int64: Character] =
        Dictionary(uniqueKeysWithValues: keyCodeByLetter.map { ($0.value, $0.key) })

    private static func splitEntries(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func parseEntry(_ entry: String) -> (id: String, keys: Set<Int64>)? {
        let parts = entry.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty else { return nil }
        let keys = Set(parts[1].lowercased().compactMap { keyCodeByLetter[$0] })
        return keys.isEmpty ? nil : (parts[0], keys)
    }

    /// "bundle.id:c,z;other.bundle.id:c" becomes [bundle id: key codes]. Entries that do not parse are skipped.
    static func decodeKeyMap(_ raw: String) -> [String: Set<Int64>] {
        var result: [String: Set<Int64>] = [:]
        for entry in splitEntries(raw) {
            guard let parsed = parseEntry(entry) else { continue }
            result[parsed.id, default: []].formUnion(parsed.keys)
        }
        return result
    }

    static func encodeKeyMap(_ map: [String: Set<Int64>]) -> String {
        map.keys.sorted().compactMap { id -> String? in
            let letters = (map[id] ?? []).compactMap { letterByKeyCode[$0] }.map(String.init).sorted().joined(separator: ",")
            return letters.isEmpty ? nil : "\(id):\(letters)"
        }.joined(separator: ";")
    }

    /// The entries of the setting that were ignored, so the settings page can say so.
    static func invalidKeyMapEntries(_ raw: String) -> [String] {
        splitEntries(raw).filter { parseEntry($0) == nil }
    }

    // MARK: - Rewriting the flags

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

    /// The opposite swap, only in the apps the user listed and only for the listed keys:
    /// a Command press with no Control or Option becomes the Control one (⌘C → ⌃C).
    static func commandAsControlFlags(keyCode: Int64,
                                      flags: CGEventFlags,
                                      frontmostBundleID: String?,
                                      keysByApp: [String: Set<Int64>]) -> CGEventFlags? {
        guard let frontmostBundleID, keysByApp[frontmostBundleID]?.contains(keyCode) == true,
              flags.contains(.maskCommand),
              !flags.contains(.maskControl),
              !flags.contains(.maskAlternate) else { return nil }
        var result = flags
        result.remove(.maskCommand)
        result.remove(CGEventFlags(rawValue: leftCommandDeviceBit | rightCommandDeviceBit))
        result.insert(.maskControl)
        result.insert(CGEventFlags(rawValue: leftControlDeviceBit))
        return result
    }

    // MARK: - Modifier keys

    // Device-dependent modifier bits (IOKit NX_DEVICE*KEYMASK). They say which
    // side was pressed; a shortcut must not keep the side bit of the modifier it replaced.
    static let leftControlDeviceBit: UInt64 = 0x0000_0001
    static let rightControlDeviceBit: UInt64 = 0x0000_2000
    static let leftCommandDeviceBit: UInt64 = 0x0000_0008
    static let rightCommandDeviceBit: UInt64 = 0x0000_0010

    static let leftControlKeyCode: CGKeyCode = 59
    static let rightControlKeyCode: CGKeyCode = 62
    static let leftCommandKeyCode: CGKeyCode = 55
    static let rightCommandKeyCode: CGKeyCode = 54

    struct Modifier: Equatable {
        let mask: CGEventFlags
        let leftKeyCode: CGKeyCode
        let rightKeyCode: CGKeyCode
        let leftDeviceBit: UInt64
        let rightDeviceBit: UInt64
    }

    static let control = Modifier(mask: .maskControl, leftKeyCode: leftControlKeyCode,
                                  rightKeyCode: rightControlKeyCode,
                                  leftDeviceBit: leftControlDeviceBit, rightDeviceBit: rightControlDeviceBit)
    static let command = Modifier(mask: .maskCommand, leftKeyCode: leftCommandKeyCode,
                                  rightKeyCode: rightCommandKeyCode,
                                  leftDeviceBit: leftCommandDeviceBit, rightDeviceBit: rightCommandDeviceBit)

    /// The key of `modifier` that is physically held, so the replay releases and restores the
    /// same one (external keyboards like Keychron have both sides).
    static func heldKeyCode(of modifier: Modifier, flags: CGEventFlags) -> CGKeyCode {
        let raw = flags.rawValue
        if raw & modifier.rightDeviceBit != 0 && raw & modifier.leftDeviceBit == 0 {
            return modifier.rightKeyCode
        }
        return modifier.leftKeyCode
    }

    /// `base` with `modifier` pressed on the side of `keyCode`.
    static func pressedFlags(base: CGEventFlags, modifier: Modifier, keyCode: CGKeyCode) -> CGEventFlags {
        let side = keyCode == modifier.rightKeyCode ? modifier.rightDeviceBit : modifier.leftDeviceBit
        return base.union(modifier.mask).union(CGEventFlags(rawValue: side))
    }

    static func heldControlKeyCode(_ flags: CGEventFlags) -> CGKeyCode {
        heldKeyCode(of: control, flags: flags)
    }

    /// Flags for the Control key-down that is restored after the replay.
    static func controlRestoreFlags(base: CGEventFlags, controlKey: CGKeyCode) -> CGEventFlags {
        pressedFlags(base: base, modifier: control, keyCode: controlKey)
    }

    /// Flags with every Control and Command bit removed (side bits included).
    static func withoutControlOrCommand(_ flags: CGEventFlags) -> CGEventFlags {
        flags.subtracting([.maskControl, .maskCommand])
            .subtracting(CGEventFlags(rawValue: leftControlDeviceBit | rightControlDeviceBit
                                      | leftCommandDeviceBit | rightCommandDeviceBit))
    }
}
