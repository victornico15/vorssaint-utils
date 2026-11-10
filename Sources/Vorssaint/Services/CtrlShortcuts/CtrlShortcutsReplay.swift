// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// The state machine behind the Ctrl shortcuts. Given a key press it says whether to swallow it
/// and which events to post instead, so the sequence can be tested without an event tap.
///
/// Many apps (Safari, Chromium, Electron) look at the modifier state itself, not just the flags of
/// the letter event. So a remapped shortcut is replayed as a real modifier change: the held
/// modifier is released, the target one is pressed, the key goes down and up, then the target is
/// released and the held modifier is pressed again if the user is still holding it.
struct CtrlReplayEngine {
    enum Direction: Equatable {
        /// Ctrl+C is sent as ⌘C (copy).
        case controlToCommand
        /// ⌘C is sent as Ctrl+C (interrupt), in the apps the user listed.
        case commandToControl

        var source: CtrlShortcutsSupport.Modifier {
            self == .controlToCommand ? CtrlShortcutsSupport.control : CtrlShortcutsSupport.command
        }
        var target: CtrlShortcutsSupport.Modifier {
            self == .controlToCommand ? CtrlShortcutsSupport.command : CtrlShortcutsSupport.control
        }
    }

    enum Action: Equatable {
        /// A modifier key changed; `flags` are the flags after the change.
        case modifier(keyCode: CGKeyCode, flags: UInt64)
        case key(keyCode: Int64, down: Bool, flags: UInt64, isRepeat: Bool)
    }

    struct Result: Equatable {
        /// True when the original event must be dropped.
        var consumed: Bool
        var actions: [Action]
    }

    /// Keys whose replay is in progress (pressed, not yet released).
    private var active = Set<Int64>()
    private var direction: Direction?
    /// The physical key of the held modifier that the replay released.
    private var heldKey: CGKeyCode = CtrlShortcutsSupport.leftControlKeyCode

    mutating func reset() {
        active.removeAll()
        direction = nil
    }

    var isReplaying: Bool { !active.isEmpty }

    private static let pass = Result(consumed: false, actions: [])

    mutating func handle(isKeyDown: Bool,
                         keyCode: Int64,
                         flags: CGEventFlags,
                         isRepeat: Bool,
                         frontmostBundleID: String?,
                         excludedBundleIDs: Set<String>,
                         commandAsControl: [String: Set<Int64>]) -> Result {
        let wasActive = active.contains(keyCode)
        if isKeyDown {
            var plan: (flags: CGEventFlags, direction: Direction)?
            if let rewritten = CtrlShortcutsSupport.rewrittenFlags(keyCode: keyCode, flags: flags,
                                                                    frontmostBundleID: frontmostBundleID,
                                                                    excludedBundleIDs: excludedBundleIDs) {
                plan = (rewritten, .controlToCommand)
            } else if let swapped = CtrlShortcutsSupport.commandAsControlFlags(keyCode: keyCode, flags: flags,
                                                                                frontmostBundleID: frontmostBundleID,
                                                                                keysByApp: commandAsControl) {
                plan = (swapped, .commandToControl)
            }
            guard let plan else {
                // A key that is already being replayed keeps repeating even if the user let go of the
                // modifier first; it must not turn into a plain letter.
                guard wasActive, isRepeat, let direction else { return Self.pass }
                let base = CtrlShortcutsSupport.withoutControlOrCommand(flags)
                let target = direction.target
                let targetFlags = CtrlShortcutsSupport.pressedFlags(base: base, modifier: target, keyCode: target.leftKeyCode)
                return Result(consumed: true,
                              actions: [.key(keyCode: keyCode, down: true, flags: targetFlags.rawValue, isRepeat: true)])
            }
            // A replay in the other direction cannot start while one is running: the modifier state would clash.
            if !active.isEmpty, direction != plan.direction { return Self.pass }

            var actions: [Action] = []
            if !wasActive || !isRepeat {
                let first = active.isEmpty
                active.insert(keyCode)
                if first {
                    direction = plan.direction
                    heldKey = CtrlShortcutsSupport.heldKeyCode(of: plan.direction.source, flags: flags)
                    let base = CtrlShortcutsSupport.withoutControlOrCommand(flags)
                    actions.append(.modifier(keyCode: heldKey, flags: base.rawValue))
                    actions.append(.modifier(keyCode: plan.direction.target.leftKeyCode, flags: plan.flags.rawValue))
                }
            }
            actions.append(.key(keyCode: keyCode, down: true, flags: plan.flags.rawValue, isRepeat: isRepeat))
            return Result(consumed: true, actions: actions)
        }

        guard wasActive, let direction else { return Self.pass }
        active.remove(keyCode)
        let source = direction.source
        let target = direction.target
        let sourceStillDown = flags.contains(source.mask)
        let base = CtrlShortcutsSupport.withoutControlOrCommand(flags)
        let targetFlags = CtrlShortcutsSupport.pressedFlags(base: base, modifier: target, keyCode: target.leftKeyCode)
        var actions: [Action] = [.key(keyCode: keyCode, down: false, flags: targetFlags.rawValue, isRepeat: false)]
        if active.isEmpty {
            actions.append(.modifier(keyCode: target.leftKeyCode, flags: base.rawValue))
            if sourceStillDown {
                let restored = CtrlShortcutsSupport.pressedFlags(base: base, modifier: source, keyCode: heldKey)
                actions.append(.modifier(keyCode: heldKey, flags: restored.rawValue))
            }
            self.direction = nil
        }
        return Result(consumed: true, actions: actions)
    }
}
