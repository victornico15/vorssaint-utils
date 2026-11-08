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
    }
}
