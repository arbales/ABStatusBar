//
//  ABStatusBarApp.swift
//  ABStatusBar
//
//  Created by Austin Bales on 2025-11-12.
//

import SwiftUI

@main
struct ABStatusBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusBarWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hide the dock icon
    NSApp.setActivationPolicy(.accessory)

    // Create a borderless window
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 800, height: 32),
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    // Configure window properties
    window.isOpaque = false
    window.backgroundColor = .clear
    window.level = .statusBar
    window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    window.isMovable = false

    // Position window at top-right
    if let screen = NSScreen.main {
      let screenFrame = screen.frame
      let windowFrame = window.frame
      let x = screenFrame.maxX - windowFrame.width
      let y = screenFrame.maxY - windowFrame.height + 1
      window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // Set the SwiftUI content
    window.contentView = NSHostingView(rootView: StatusBarView())

    // Show the window
    window.orderFrontRegardless()

    self.statusBarWindow = window
  }
}
