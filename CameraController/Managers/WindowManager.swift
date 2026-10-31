//
//  WindowManager.swift
//  CameraController
//
//  Created by Itay Brenner on 25/1/22.
//  Copyright © 2022 Itaysoft. All rights reserved.
//

import Foundation
import AppKit
import SwiftUI

class WindowManager: NSObject {
    static let shared = WindowManager()

    private var popover: NSPopover?
    private var isShowing: Bool = false

    func toggleShowWindow(from button: NSButton) {
        if isShowing {
            closeWindow()
        } else {
            showWindow(from: button)
        }
    }

    func showWindow(from button: NSButton) {
        NotificationCenter.default.post(name: .windowOpen, object: nil)

        let contentView = ContentView()

        // Let the SwiftUI content (via `.fixedSize()` in ContentView) drive the popover
        // size from the first frame. Setting an explicit initial `contentSize` smaller
        // than the actual content used to cause two visible problems:
        //   1. The popover would mount at the wrong size, then resize — and macOS
        //      shifts the popover *upward* into the menu bar when growing.
        //   2. Switching tabs (Basic ↔ Settings) wouldn't propagate the new height.
        // On macOS 13+ `sizingOptions = .preferredContentSize` keeps the popover
        // synced to SwiftUI layout changes for the lifetime of the popover.
        let hosting = NSHostingController(rootView: contentView)
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = .preferredContentSize
        }

        let popover = NSPopover()
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self
        self.popover = popover

        DispatchQueue.main.async { [weak self] in
            self?.popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self?.popover?.contentViewController?.view.window?.makeKey()
        }

        isShowing = true
    }

    func closeWindow() {
        isShowing = false

        popover?.performClose(nil)
    }
}

extension WindowManager: NSPopoverDelegate {
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        return true
    }

    func popoverWillClose(_ notification: Notification) {
        NotificationCenter.default.post(name: .windowClose, object: nil)
        isShowing = false
    }

    func popoverDidDetach(_ popover: NSPopover) {
        // Disable dragging, only dragging with the preview is allowed
        popover.contentViewController?.view.window?.isMovableByWindowBackground = false
    }
}
