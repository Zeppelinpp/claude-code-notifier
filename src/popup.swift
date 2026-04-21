import Cocoa
import AppKit

class HoverView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}

class ActionHandler: NSObject {
    let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
    }
    @objc func run() {
        action()
    }
}

func showNotification(title: String, subtitle: String, informativeText: String, terminalBundleID: String) {
    // Play Glass sound
    if let sound = NSSound(named: "Glass") {
        sound.play()
    }

    // Determine screen based on mouse position
    let mouseLoc = NSEvent.mouseLocation
    var targetScreen: NSScreen?
    for screen in NSScreen.screens {
        if NSMouseInRect(mouseLoc, screen.frame, false) {
            targetScreen = screen
            break
        }
    }
    guard let screen = targetScreen ?? NSScreen.main else { return }

    let screenFrame = screen.visibleFrame
    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

    // Window dimensions
    let padTop: CGFloat = 16
    let padBottom: CGFloat = 13
    let padH: CGFloat = 16
    let padIconText: CGFloat = 12
    let iconSize: CGFloat = 40
    let closeSize: CGFloat = 16
    let closePad: CGFloat = 8

    let textWidth: CGFloat = 220
    let titleHeight: CGFloat = 18
    let subtitleHeight: CGFloat = 16
    let bodyHeight: CGFloat = 16
    let textBlockHeight = titleHeight + subtitleHeight + bodyHeight + 6

    let contentHeight = max(iconSize, textBlockHeight)
    let windowWidth = padH + iconSize + padIconText + textWidth + padH + closeSize + closePad
    let windowHeight = padTop + contentHeight + padBottom

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = true
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    // Visual effect view (frosted glass)
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = .popover
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 18
    visualEffectView.layer?.masksToBounds = true
    if #available(macOS 10.15, *) {
        visualEffectView.layer?.cornerCurve = .continuous
    }
    window.contentView = visualEffectView

    // Icon
    let iconView = NSImageView()
    iconView.imageScaling = .scaleProportionallyUpOrDown
    if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
       let icon = NSImage(contentsOfFile: iconPath) {
        iconView.image = icon
    }
    iconView.frame = NSRect(x: padH, y: (windowHeight - iconSize) / 2, width: iconSize, height: iconSize)
    visualEffectView.addSubview(iconView)

    // Text container
    let textX = padH + iconSize + padIconText
    let textY = (windowHeight - textBlockHeight) / 2

    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
    titleLabel.textColor = isDark ? .white : .black
    titleLabel.frame = NSRect(x: textX, y: textY + subtitleHeight + bodyHeight + 4, width: textWidth, height: titleHeight)
    visualEffectView.addSubview(titleLabel)

    let subtitleLabel = NSTextField(labelWithString: subtitle)
    subtitleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    subtitleLabel.textColor = isDark ? NSColor(white: 0.7, alpha: 1) : NSColor(white: 0.3, alpha: 1)
    subtitleLabel.frame = NSRect(x: textX, y: textY + bodyHeight + 2, width: textWidth, height: subtitleHeight)
    visualEffectView.addSubview(subtitleLabel)

    let bodyLabel = NSTextField(labelWithString: informativeText)
    bodyLabel.font = NSFont.systemFont(ofSize: 11)
    bodyLabel.textColor = isDark ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.4, alpha: 1)
    bodyLabel.frame = NSRect(x: textX, y: textY, width: textWidth, height: bodyHeight)
    visualEffectView.addSubview(bodyLabel)

    // Close button (hover visible)
    let closeBtn = NSButton()
    closeBtn.bezelStyle = .circular
    closeBtn.title = "×"
    closeBtn.font = NSFont.systemFont(ofSize: 12, weight: .medium)
    closeBtn.isBordered = false
    closeBtn.wantsLayer = true
    closeBtn.layer?.backgroundColor = NSColor.clear.cgColor
    closeBtn.layer?.cornerRadius = closeSize / 2
    closeBtn.alphaValue = 0

    let closeHandler = ActionHandler {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 0
        } completionHandler: {
            window.close()
            NSApp.terminate(nil)
        }
    }
    closeBtn.target = closeHandler
    closeBtn.action = #selector(ActionHandler.run)
    // Retain handler to prevent deallocation
    objc_setAssociatedObject(closeBtn, "handler", closeHandler, .OBJC_ASSOCIATION_RETAIN)

    closeBtn.frame = NSRect(x: windowWidth - closeSize - closePad, y: windowHeight - closeSize - closePad, width: closeSize, height: closeSize)
    visualEffectView.addSubview(closeBtn)

    // Hover tracking for close button visibility
    let hoverView = HoverView()
    hoverView.frame = visualEffectView.bounds
    hoverView.onMouseEntered = {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            closeBtn.animator().alphaValue = 0.6
        }
    }
    hoverView.onMouseExited = {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            closeBtn.animator().alphaValue = 0
        }
    }
    visualEffectView.addSubview(hoverView)

    // Position window
    let x = screenFrame.maxX - windowWidth - 20
    let y = screenFrame.maxY - windowHeight - 20
    window.setFrameOrigin(NSPoint(x: x, y: y))

    // Click to focus the terminal app that originated the notification
    let clickHandler = ActionHandler {
        if !terminalBundleID.isEmpty,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == terminalBundleID }) {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
        } else if let app = NSWorkspace.shared.frontmostApplication {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }
        window.close()
        NSApp.terminate(nil)
    }
    let clickGesture = NSClickGestureRecognizer(target: clickHandler, action: #selector(ActionHandler.run))
    objc_setAssociatedObject(clickGesture, "handler", clickHandler, .OBJC_ASSOCIATION_RETAIN)
    visualEffectView.addGestureRecognizer(clickGesture)

    // Auto-dismiss after 8 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 0
        } completionHandler: {
            window.close()
            NSApp.terminate(nil)
        }
    }

    window.makeKeyAndOrderFront(nil)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let title = args.count > 1 ? args[1] : "Claude Code"
        let subtitle = args.count > 2 ? args[2] : ""
        let body = args.count > 3 ? args[3] : "Wait for Input"
        let bundleID = args.count > 4 ? args[4] : ""
        showNotification(title: title, subtitle: subtitle, informativeText: body, terminalBundleID: bundleID)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
