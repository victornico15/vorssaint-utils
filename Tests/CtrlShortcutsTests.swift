// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum CtrlShortcutsTests {
    static func run(_ suite: TestSuite) {
        let none = Set<String>()
        let cmd = CGEventFlags.maskCommand.union(CGEventFlags(rawValue: CtrlShortcutsSupport.leftCommandDeviceBit))
        func rewrite(_ key: Int64, _ flags: CGEventFlags, app: String? = "com.apple.TextEdit",
                     excluded: Set<String> = []) -> CGEventFlags? {
            CtrlShortcutsSupport.rewrittenFlags(keyCode: key, flags: flags,
                                                frontmostBundleID: app, excludedBundleIDs: excluded)
        }

        for (name, key) in [("select all", CtrlShortcutsSupport.selectAllKey),
                            ("copy", CtrlShortcutsSupport.copyKey),
                            ("paste", CtrlShortcutsSupport.pasteKey),
                            ("save", CtrlShortcutsSupport.saveKey)] {
            let result = rewrite(key, .maskControl)
            suite.expect(result == cmd, "Ctrl+\(name) becomes Command+\(name)")
        }
        suite.expect(rewrite(CtrlShortcutsSupport.undoKey, [.maskControl, .maskShift]) == cmd.union(.maskShift),
                     "Shift is kept when Ctrl+Shift+Z becomes Command+Shift+Z")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, .maskCommand) == nil,
                     "Command+C is left alone")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, [.maskControl, .maskCommand]) == nil,
                     "Ctrl+Command+C is left alone")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, [.maskControl, .maskAlternate]) == nil,
                     "Ctrl+Option+C is left alone")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, []) == nil, "plain C is left alone")
        suite.expect(rewrite(12, .maskControl) == nil, "Ctrl+Q is not remapped")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, .maskControl, app: "com.apple.Terminal",
                             excluded: ["com.apple.Terminal"]) == nil,
                     "an excluded app keeps Ctrl+C")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, .maskControl, app: nil, excluded: ["x"]) == cmd,
                     "an unknown frontmost app is not excluded")
        suite.expect(rewrite(CtrlShortcutsSupport.copyKey, .maskControl, excluded: none) == cmd,
                     "an empty exclusion list remaps everywhere")

        // Keychron and other external keyboards report which Control side is
        // held; the side bit must not survive into the Command shortcut.
        let leftCtrl = CGEventFlags(rawValue: 0x40101)
        let rightCtrl = CGEventFlags(rawValue: 0x42100)
        let fromLeft = rewrite(CtrlShortcutsSupport.selectAllKey, leftCtrl)
        let fromRight = rewrite(CtrlShortcutsSupport.selectAllKey, rightCtrl)
        suite.expect(fromLeft?.rawValue == 0x100108, "left Ctrl+A from an external keyboard becomes left Command+A")
        suite.expect(fromRight?.rawValue == 0x100108, "right Ctrl+A becomes left Command+A without a Control side bit")
        suite.expect(CtrlShortcutsSupport.heldControlKeyCode(leftCtrl) == CtrlShortcutsSupport.leftControlKeyCode,
                     "the left Control key is detected from its side bit")
        suite.expect(CtrlShortcutsSupport.heldControlKeyCode(rightCtrl) == CtrlShortcutsSupport.rightControlKeyCode,
                     "the right Control key is detected from its side bit")
        suite.expect(CtrlShortcutsSupport.controlRestoreFlags(base: CGEventFlags(rawValue: 0x100),
                                                              controlKey: CtrlShortcutsSupport.rightControlKeyCode).rawValue == 0x42100,
                     "the right Control key is restored with its own side bit")
        suite.expect(CtrlShortcutsSupport.withoutControlOrCommand(CGEventFlags(rawValue: 0x142109)).rawValue == 0x100,
                     "removing Control and Command also drops their side bits")

        let decoded = CtrlShortcutsSupport.decodeExcluded(" a.b , c.d\ne.f,,")
        suite.expect(decoded == ["a.b", "c.d", "e.f"], "exclusions split on commas and newlines and drop blanks")
        suite.expect(CtrlShortcutsSupport.encodeExcluded(["a", " a ", "", "b"]) == "a,b",
                     "encoding removes duplicates and blanks")
        suite.expect(CtrlShortcutsSupport.decodeExcluded(
            CtrlShortcutsSupport.encodeExcluded(CtrlShortcutsSupport.defaultExcludedBundleIDs)
        ).contains("com.apple.Terminal"), "Terminal is excluded by default")

        // Applying the rewrite to a real event edits its flags in place.
        if let event = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true) {
            event.flags = .maskControl
            if let flags = rewrite(8, event.flags) { event.flags = flags }
            suite.expect(event.flags.contains(.maskCommand) && !event.flags.contains(.maskControl),
                         "a Ctrl+C event is rewritten to Command+C")
        }
        for language in AppLanguage.allCases {
            let text = FeatureStrings.ctrlShortcuts(language)
            suite.expect(!text.title.isEmpty && !text.caption.isEmpty && !text.hubDescription.isEmpty,
                         "Ctrl shortcuts strings exist for \(language)")
        }
        swapTests(suite)
    }

    /// Command sent as Control in the listed apps (Alt+C on a PC-style keyboard interrupting a terminal)
    /// and the exact sequence of events the replay posts.
    static func swapTests(_ suite: TestSuite) {
        let map = CtrlShortcutsSupport.decodeKeyMap("com.a.b:c,Z ; com.c.d:a;bad;:c;com.e.f:1;com.a.b:v")
        suite.expect(map == ["com.a.b": [8, 6, 9], "com.c.d": [0]],
                     "the key map keeps the valid entries and merges a repeated app")
        suite.expect(CtrlShortcutsSupport.invalidKeyMapEntries("com.a.b:c;bad;:c;com.e.f:1") == ["bad", ":c", "com.e.f:1"],
                     "entries without an app, without a colon or without a known letter are reported")
        suite.expect(CtrlShortcutsSupport.encodeKeyMap(["com.c.d": [0], "com.a.b": [8, 6]]) == "com.a.b:c,z;com.c.d:a",
                     "the key map is written back sorted")
        let defaults = CtrlShortcutsSupport.decodeKeyMap(CtrlShortcutsSupport.defaultCommandAsControl)
        suite.expect(defaults["com.microsoft.VSCode"] == [8] && defaults["com.anthropic.claudefordesktop"] == [8],
                     "Claude and VS Code send Command+C as Ctrl+C by default")
        suite.expect(CtrlShortcutsSupport.encodeKeyMap(defaults) == CtrlShortcutsSupport.defaultCommandAsControl,
                     "the default key map survives a round trip")

        let listed: [String: Set<Int64>] = ["com.a.b": [8, 2]]
        func swap(_ key: Int64, _ raw: UInt64, app: String? = "com.a.b") -> CGEventFlags? {
            CtrlShortcutsSupport.commandAsControlFlags(keyCode: key, flags: CGEventFlags(rawValue: raw),
                                                       frontmostBundleID: app, keysByApp: listed)
        }
        suite.expect(swap(8, 0x100108)?.rawValue == 0x40101, "Command+C becomes Ctrl+C in a listed app")
        suite.expect(swap(8, 0x100110)?.rawValue == 0x40101, "the right Command key also becomes the left Control, with no Command bit left")
        suite.expect(swap(8, 0x120108)?.rawValue == 0x60101, "Shift is kept when Command+Shift+C becomes Ctrl+Shift+C")
        suite.expect(swap(9, 0x100108) == nil, "a key that is not listed stays Command")
        suite.expect(swap(8, 0x100108, app: "com.other") == nil, "an app that is not listed keeps Command+C")
        suite.expect(swap(8, 0x100108, app: nil) == nil, "an unknown frontmost app keeps Command+C")
        suite.expect(swap(8, 0x180128) == nil, "Command+Option+C is left alone")
        suite.expect(swap(8, 0x140109) == nil, "Control+Command+C is left alone")
        suite.expect(swap(8, 0x40101) == nil, "Ctrl+C is not touched by this swap")
        suite.expect(CtrlShortcutsSupport.heldKeyCode(of: CtrlShortcutsSupport.command, flags: CGEventFlags(rawValue: 0x100110)) == 54,
                     "the right Command key is detected from its side bit")
        suite.expect(CtrlShortcutsSupport.heldKeyCode(of: CtrlShortcutsSupport.command, flags: CGEventFlags(rawValue: 0x100108)) == 55,
                     "the left Command key is detected from its side bit")

        // The events the replay posts, step by step.
        var engine = CtrlReplayEngine()
        func press(_ down: Bool, _ key: Int64, _ raw: UInt64, isRepeat: Bool = false, app: String? = "com.a.b") -> CtrlReplayEngine.Result {
            engine.handle(isKeyDown: down, keyCode: key, flags: CGEventFlags(rawValue: raw), isRepeat: isRepeat,
                          frontmostBundleID: app, excludedBundleIDs: [], commandAsControl: listed)
        }
        typealias A = CtrlReplayEngine.Action

        // Ctrl+C (left): Control up, Command down, C down ... C up, Command up, Control down again.
        var r = press(true, 8, 0x40101)
        suite.expect(r.consumed && r.actions == [.modifier(keyCode: 59, flags: 0x100),
                                                .modifier(keyCode: 55, flags: 0x100108),
                                                .key(keyCode: 8, down: true, flags: 0x100108, isRepeat: false)],
                     "Ctrl+C down is replayed as a real Command+C press")
        r = press(true, 8, 0x40101, isRepeat: true)
        suite.expect(r.consumed && r.actions == [.key(keyCode: 8, down: true, flags: 0x100108, isRepeat: true)],
                     "a repeat of the held key posts only the key")
        r = press(true, 8, 0x100, isRepeat: true)
        suite.expect(r.consumed && r.actions == [.key(keyCode: 8, down: true, flags: 0x100108, isRepeat: true)],
                     "a repeat after the Control key was let go still stays Command+C")
        r = press(false, 8, 0x40101)
        suite.expect(r.consumed && r.actions == [.key(keyCode: 8, down: false, flags: 0x100108, isRepeat: false),
                                                .modifier(keyCode: 55, flags: 0x100),
                                                .modifier(keyCode: 59, flags: 0x40101)],
                     "Ctrl+C up releases Command and presses Control again when it is still held")
        suite.expect(!engine.isReplaying, "nothing is replaying after the key went up")
        r = press(true, 8, 0x40101); _ = press(false, 8, 0x100)
        suite.expect(press(false, 8, 0x40101) == CtrlReplayEngine.Result(consumed: false, actions: []),
                     "a key up that never had a replay is not touched")

        // Ctrl+C on the right Control key keeps its side.
        r = press(true, 8, 0x42100)
        suite.expect(r.actions.first == .modifier(keyCode: 62, flags: 0x100), "the right Control key is the one released")
        r = press(false, 8, 0x42100)
        suite.expect(r.actions.last == .modifier(keyCode: 62, flags: 0x42100), "the right Control key is the one pressed again")

        // Command+C in a listed app: Command up, Control down, C ... then back.
        r = press(true, 8, 0x100108)
        suite.expect(r.consumed && r.actions == [.modifier(keyCode: 55, flags: 0x100),
                                                .modifier(keyCode: 59, flags: 0x40101),
                                                .key(keyCode: 8, down: true, flags: 0x40101, isRepeat: false)],
                     "Command+C down is replayed as a real Ctrl+C press")
        r = press(false, 8, 0x100108)
        suite.expect(r.consumed && r.actions == [.key(keyCode: 8, down: false, flags: 0x40101, isRepeat: false),
                                                .modifier(keyCode: 59, flags: 0x100),
                                                .modifier(keyCode: 55, flags: 0x100108)],
                     "Command+C up releases Control and presses Command again when it is still held")
        r = press(true, 8, 0x100110)
        suite.expect(r.actions.first == .modifier(keyCode: 54, flags: 0x100), "the right Command key is the one released")
        r = press(false, 8, 0x100110)
        suite.expect(r.actions.last == .modifier(keyCode: 54, flags: 0x100110), "the right Command key is the one pressed again")

        // What must not change.
        suite.expect(press(true, 9, 0x100108) == CtrlReplayEngine.Result(consumed: false, actions: []),
                     "Command+V is left alone in a listed app")
        suite.expect(press(true, 8, 0x100108, app: "com.other") == CtrlReplayEngine.Result(consumed: false, actions: []),
                     "Command+C is left alone in an app that is not listed")
        r = press(true, 9, 0x40101, app: "com.a.b")
        suite.expect(r.consumed && r.actions.last == .key(keyCode: 9, down: true, flags: 0x100108, isRepeat: false),
                     "Ctrl+V is still sent as Command+V in a listed app")
        _ = press(false, 9, 0x40101)

        // A replay in the other direction cannot start while one is running.
        _ = press(true, 8, 0x40101)
        suite.expect(press(true, 2, 0x100108) == CtrlReplayEngine.Result(consumed: false, actions: []),
                     "Command+D is not swapped while a Ctrl+C replay is running")
        engine.reset()
        suite.expect(!engine.isReplaying, "reset clears a running replay")

        // A whole batch of shortcuts, each pressed and released the way a keyboard does it: every one arrives as
        // expected and no replay is left running, so no modifier can stay stuck.
        let modMask: UInt64 = 0x1E0000   // Shift, Control, Option, Command
        let batch: [(name: String, key: Int64, flags: UInt64, delivered: UInt64)] = [
            ("Command+C", 8, 0x100108, 0x40000), ("Ctrl+C", 8, 0x40101, 0x100000),
            ("Command+V", 9, 0x100108, 0x100000), ("Ctrl+V", 9, 0x40101, 0x100000),
            ("Ctrl+A", 0, 0x40101, 0x100000), ("Command+A", 0, 0x100108, 0x100000),
            ("Command+Option+C", 8, 0x180128, 0x180000), ("Ctrl+Command+C", 8, 0x140109, 0x140000),
            ("Command+Shift+C", 8, 0x12010A, 0x60000), ("Ctrl+Shift+C", 8, 0x60103, 0x120000),
            ("plain C", 8, 0x100, 0),
        ]
        var batchEngine = CtrlReplayEngine()
        for item in batch {
            let down = batchEngine.handle(isKeyDown: true, keyCode: item.key, flags: CGEventFlags(rawValue: item.flags),
                                          isRepeat: false, frontmostBundleID: "com.a.b", excludedBundleIDs: [],
                                          commandAsControl: listed)
            var delivered = item.flags & modMask
            if down.consumed, case .key(_, true, let raw, _)? = down.actions.last { delivered = raw & modMask }
            suite.expect(delivered == item.delivered, "\(item.name) arrives with the expected modifiers")
            _ = batchEngine.handle(isKeyDown: false, keyCode: item.key, flags: CGEventFlags(rawValue: item.flags),
                                   isRepeat: false, frontmostBundleID: "com.a.b", excludedBundleIDs: [],
                                   commandAsControl: listed)
        }
        suite.expect(!batchEngine.isReplaying, "no replay is left running after a batch of shortcuts")
    }
}
