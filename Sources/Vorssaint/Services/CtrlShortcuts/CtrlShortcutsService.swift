// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation

/// Turns Ctrl+A / C / V / X / Z into the Command versions system-wide, except
/// in excluded apps. Uses one CGEventTap that edits the flags of the event in
/// place. Needs the Accessibility permission, like the other keyboard features.
final class CtrlShortcutsService: ObservableObject {
    static let shared = CtrlShortcutsService()

    @Published private(set) var isRunning = false

    private let eventLock = NSLock()
    private var enabled = false
    private var excluded = Set<String>()
    private var frontmostBundleID: String?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var workspaceObserver: NSObjectProtocol?

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
            isRunning = false
            return
        }
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
        isRunning = false
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
        let newFlags = eventLock.withLock { () -> CGEventFlags? in
            guard enabled else { return nil }
            return CtrlShortcutsSupport.rewrittenFlags(keyCode: keyCode,
                                                       flags: event.flags,
                                                       frontmostBundleID: frontmostBundleID,
                                                       excludedBundleIDs: excluded)
        }
        if let newFlags { event.flags = newFlags }
        return Unmanaged.passUnretained(event)
    }
}
