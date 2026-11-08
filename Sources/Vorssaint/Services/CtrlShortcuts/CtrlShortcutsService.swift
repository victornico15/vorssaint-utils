// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation

/// Turns Ctrl+A / C / V / X / Z / S into the Command versions system-wide, except
/// in excluded apps. Uses one CGEventTap that edits the flags of the event in
/// place. Needs Accessibility and Input Monitoring: without Input Monitoring
/// macOS refuses a keyboard tap.
final class CtrlShortcutsService: ObservableObject {
    static let shared = CtrlShortcutsService()

    @Published private(set) var isRunning = false

    private let eventLock = NSLock()
    private var enabled = false
    private var excluded = Set<String>()
    private var frontmostBundleID: String?
    /// Keys whose Command replay is in progress (pressed, not yet released).
    private var active = Set<Int64>()
    /// The Control key (left or right) the current replay released.
    private var heldControlKey = CtrlShortcutsSupport.leftControlKeyCode
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var workspaceObserver: NSObjectProtocol?
    private var retryTimer: Timer?
    private var requestedListenAccess = false

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        let defaults = UserDefaults.standard
        let wanted = AppFeature.ctrlShortcuts.isAvailable
            && defaults.bool(forKey: DefaultsKey.ctrlShortcutsEnabled)
        let excludedIDs = CtrlShortcutsSupport.decodeExcluded(
            defaults.string(forKey: DefaultsKey.ctrlShortcutsExcludedApps) ?? ""
        )
        eventLock.withLock {
            enabled = wanted
            excluded = excludedIDs
        }
        if SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                               accessibilityGranted: AXIsProcessTrusted(),
                                               sessionIsActive: SessionActivity.shared.isActive) {
            start()
        } else {
            stop()
        }
    }

    func suspend() { stop() }

    private func start() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.start() }
            return
        }
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<CtrlShortcutsService>.fromOpaque(userInfo).takeUnretainedValue()
                return service.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // macOS refuses a keyboard tap without Input Monitoring. Ask once
            // (this lists the app in Privacy & Security), then retry on a
            // timer so the feature starts as soon as the switch is turned on.
            isRunning = false
            if !requestedListenAccess {
                requestedListenAccess = true
                _ = CGRequestListenEventAccess()
            }
            writeStatus("tap-failed ax=\(AXIsProcessTrusted()) listen=\(CGPreflightListenEventAccess()) post=\(CGPreflightPostEventAccess())")
            scheduleRetry()
            return
        }
        retryTimer?.invalidate()
        retryTimer = nil
        writeStatus("tap-created")
        // The event handler runs on the main run loop, so reading the cached
        // frontmost app needs no extra synchronisation beyond eventLock.
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        runLoopSource = source
        updateFrontmost(NSWorkspace.shared.frontmostApplication)
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.updateFrontmost(app)
        }
        isRunning = true
    }

    private func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return
        }
        retryTimer?.invalidate()
        retryTimer = nil
        writeStatus("stopped wanted=\(eventLock.withLock { enabled }) ax=\(AXIsProcessTrusted())")
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        runLoopSource = nil
        eventLock.withLock { active.removeAll() }
        isRunning = false
    }

    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self, self.tap == nil else { return }
            self.syncWithPreferences()
        }
    }

    /// One line describing the last start attempt, for troubleshooting.
    private func writeStatus(_ line: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vorssaint-ctrl-shortcuts-status.txt")
        try? (line + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private func updateFrontmost(_ app: NSRunningApplication?) {
        eventLock.withLock { frontmostBundleID = app?.bundleIdentifier }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap, SessionActivity.shared.isActive, AXIsProcessTrusted() {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp, !OwnKeyEvent.isPosted(event) else {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let plan = eventLock.withLock { () -> (CGEventFlags?, Bool) in
            guard enabled else { return (nil, false) }
            let rewritten = CtrlShortcutsSupport.rewrittenFlags(keyCode: keyCode,
                                                                flags: flags,
                                                                frontmostBundleID: frontmostBundleID,
                                                                excludedBundleIDs: excluded)
            return (rewritten, active.contains(keyCode))
        }
        let (rewritten, wasActive) = plan

        if type == .keyDown, let rewritten {
            // Many apps (Safari, Chromium and Electron) look at the modifier
            // state itself, not just the flags of the letter event. So the
            // whole sequence is replayed as a real Command press.
            if !wasActive || !isRepeat {
                let alreadyCommand = eventLock.withLock { () -> Bool in
                    let busy = !active.isEmpty
                    active.insert(keyCode)
                    return busy
                }
                if !alreadyCommand {
                    let controlKey = CtrlShortcutsSupport.heldControlKeyCode(flags)
                    eventLock.withLock { heldControlKey = controlKey }
                    let base = CtrlShortcutsSupport.withoutControlOrCommand(flags)
                    postModifier(keyCode: controlKey, flags: base)
                    postModifier(keyCode: CtrlShortcutsSupport.leftCommandKeyCode, flags: rewritten)
                }
            }
            postKey(keyCode, down: true, flags: rewritten, repeatFlag: isRepeat)
            return nil
        }
        if type == .keyUp, wasActive {
            let ctrlStillDown = flags.contains(.maskControl)
            let base = CtrlShortcutsSupport.withoutControlOrCommand(flags)
            let (lastOne, controlKey) = eventLock.withLock { () -> (Bool, CGKeyCode) in
                active.remove(keyCode)
                return (active.isEmpty, heldControlKey)
            }
            let commandFlags = base.union(.maskCommand)
                .union(CGEventFlags(rawValue: CtrlShortcutsSupport.leftCommandDeviceBit))
            postKey(keyCode, down: false, flags: commandFlags, repeatFlag: false)
            if lastOne {
                postModifier(keyCode: CtrlShortcutsSupport.leftCommandKeyCode, flags: base)
                if ctrlStillDown {
                    postModifier(keyCode: controlKey,
                                 flags: CtrlShortcutsSupport.controlRestoreFlags(base: base, controlKey: controlKey))
                }
            }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }


    private func postKey(_ keyCode: Int64, down: Bool, flags: CGEventFlags, repeatFlag: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: down) else { return }
        event.flags = flags
        if repeatFlag { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
        event.post(tap: .cgSessionEventTap)
    }

    private func postModifier(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        event.type = .flagsChanged
        event.flags = flags
        event.post(tap: .cgSessionEventTap)
    }
}
