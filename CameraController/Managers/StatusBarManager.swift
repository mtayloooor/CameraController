//
//  StatusBarManager.swift
//  CameraController
//
//  Created by Itay Brenner on 25/1/22.
//  Copyright © 2022 Itaysoft. All rights reserved.
//

import Foundation
import Cocoa

class StatusBarManager {
    var statusBarItem: NSStatusItem!

    init() {
        // Fix for SwiftUI Previews adding Statusbar Items constantly
        #if DEBUG
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            return
        }
        #endif

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusBarItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "camera.fill",
                               accessibilityDescription: "Camera Controller")
        button.imageScaling = NSImageScaling.scaleProportionallyDown
        button.target = self
        button.action = #selector(handleClick(_:))
        // Receive both left-click (open popover) and right-click (context menu).
        // Treat ctrl+left-click as right-click too, matching standard macOS conventions.
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - Click handling

    @objc
    private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)

        if isRightClick {
            showContextMenu()
        } else {
            showCustomView()
        }
    }

    @objc
    func showCustomView() {
        guard let button = statusBarItem?.button else {
            return
        }

        WindowManager.shared.toggleShowWindow(from: button)
    }

    // MARK: - Context menu

    private func showContextMenu() {
        guard let button = statusBarItem?.button else { return }

        // Assign the menu to the status item temporarily so it appears in the
        // standard status-bar location and dismisses properly. We strip it again
        // immediately after, so subsequent left-clicks still trigger our action
        // handler rather than auto-popping the menu.
        let menu = buildContextMenu()
        statusBarItem.menu = menu
        button.performClick(nil)
        statusBarItem.menu = nil
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open CameraController",
            action: #selector(showCustomView),
            keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        // "Apply <profile>" entries — listed inline, no submenu.
        // First the built-in default, then user-saved profiles in their saved order.
        let hasDevice = DevicesManager.shared.selectedDevice?.controller != nil

        let defaultItem = NSMenuItem(
            title: "Apply Camera Default",
            action: #selector(applyDefaultProfile),
            keyEquivalent: "")
        defaultItem.target = self
        defaultItem.isEnabled = hasDevice
        menu.addItem(defaultItem)

        for (index, profile) in ProfileManager.shared.profiles.enumerated() {
            let item = NSMenuItem(
                title: "Apply \(profile.name)",
                action: #selector(applyProfile(_:)),
                keyEquivalent: "")
            item.target = self
            item.tag = index
            item.isEnabled = hasDevice && profile.settings != nil
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // We manage enabled state explicitly above; disable AppKit's auto-enabling
        // so it doesn't second-guess us based on responder chain.
        menu.autoenablesItems = false

        return menu
    }

    @objc
    private func applyDefaultProfile() {
        DevicesManager.shared.selectedDevice?.controller?.resetDefault()
    }

    @objc
    private func applyProfile(_ sender: NSMenuItem) {
        let profiles = ProfileManager.shared.profiles
        guard sender.tag >= 0, sender.tag < profiles.count else { return }
        guard let settings = profiles[sender.tag].settings else { return }
        DevicesManager.shared.selectedDevice?.controller?.set(settings)
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
