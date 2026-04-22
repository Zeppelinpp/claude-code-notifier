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

class NotificationWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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

// MARK: - Nordic Palette
extension NSColor {
    static let nord0 = NSColor(red: 0.180, green: 0.204, blue: 0.251, alpha: 1.0)  // #2E3440
    static let nord1 = NSColor(red: 0.231, green: 0.259, blue: 0.322, alpha: 1.0)  // #3B4252
    static let nord4 = NSColor(red: 0.847, green: 0.871, blue: 0.914, alpha: 1.0)  // #D8DEE9
    static let nord6 = NSColor(red: 0.506, green: 0.631, blue: 0.757, alpha: 1.0)  // #81A1C1
    static let nord8 = NSColor(red: 0.533, green: 0.753, blue: 0.816, alpha: 1.0)  // #88C0D0
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

    // Layout constants — expanded for markdown
    let padTop: CGFloat = 14
    let padBottom: CGFloat = 14
    let padH: CGFloat = 16
    let padIconText: CGFloat = 12
    let closeSize: CGFloat = 16
    let closePad: CGFloat = 8

    let textWidth: CGFloat = 300
    let titleHeight: CGFloat = 18
    let gapTitleSubtitle: CGFloat = 4
    let gapSubtitleBody: CGFloat = 6
    let minIconSize: CGFloat = 44
    let maxIconSize: CGFloat = 56
    let bodyInsetY: CGFloat = 4
    let maxBodyHeight: CGFloat = 90

    let bodyFont = NSFont.systemFont(ofSize: 12)
    let bodyColor: NSColor = isDark ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.4, alpha: 1)
    let collapsed = informativeText
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    let maxBodyChars = 140
    let message = collapsed.count > maxBodyChars
        ? String(collapsed.prefix(maxBodyChars)) + "..."
        : collapsed

    // ---- Subtitle: code-block style path ----
    let codePadH: CGFloat = 8
    let codePadV: CGFloat = 3
    let codeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    let codeLabel = NSTextField(labelWithString: subtitle)
    codeLabel.font = codeFont
    codeLabel.textColor = .nord4
    codeLabel.sizeToFit()
    let codeBlockWidth = min(codeLabel.frame.width + codePadH * 2, textWidth)
    let codeBlockHeight = codeLabel.frame.height + codePadV * 2

    // ---- Build body attributed string first (for dynamic height) ----
    var bodyAttrString: NSAttributedString
    if #available(macOS 12.0, *) {
        if let data = message.data(using: .utf8),
           let attributedString = try? NSAttributedString(
               markdown: data,
               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
           ) {
            let mutable = NSMutableAttributedString(attributedString: attributedString)
            let fullRange = NSRange(location: 0, length: mutable.length)
            mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                if value == nil {
                    mutable.addAttribute(.foregroundColor, value: bodyColor, range: range)
                }
            }
            mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                if value == nil {
                    mutable.addAttribute(.font, value: bodyFont, range: range)
                }
            }
            mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                if let font = value as? NSFont {
                    let name = font.fontName.lowercased()
                    if name.contains("mono") || name.contains("menlo") || name.contains("courier") {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
                    }
                }
            }
            bodyAttrString = mutable
        } else {
            bodyAttrString = NSAttributedString(
                string: message,
                attributes: [.foregroundColor: bodyColor, .font: bodyFont]
            )
        }
    } else {
        bodyAttrString = NSAttributedString(
            string: message,
            attributes: [.foregroundColor: bodyColor, .font: bodyFont]
        )
    }

    // Calculate body height dynamically, capped at maxBodyHeight
    let bodyStorage = NSTextStorage(attributedString: bodyAttrString)
    let bodyLayoutManager = NSLayoutManager()
    let bodyTextContainer = NSTextContainer(size: NSSize(width: textWidth, height: .greatestFiniteMagnitude))
    bodyTextContainer.lineFragmentPadding = 0
    bodyLayoutManager.addTextContainer(bodyTextContainer)
    bodyStorage.addLayoutManager(bodyLayoutManager)
    bodyLayoutManager.glyphRange(for: bodyTextContainer)
    let rawBodyHeight = bodyLayoutManager.usedRect(for: bodyTextContainer).height
    let bodyViewHeight = min(rawBodyHeight + bodyInsetY * 2, maxBodyHeight)

    // ---- Overall dimensions ----
    let textBlockHeight = titleHeight + gapTitleSubtitle + codeBlockHeight + gapSubtitleBody + bodyViewHeight
    let iconSize = min(max(textBlockHeight - 2, minIconSize), maxIconSize)
    let contentHeight = max(iconSize, textBlockHeight)
    let windowWidth = padH + iconSize + padIconText + textWidth + padH + closeSize + closePad
    let windowHeight = padTop + contentHeight + padBottom

    // ---- Window ----
    let window = NotificationWindow(
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

    // Background view (opaque dark base for readability on any background)
    let backgroundView = NSView()
    backgroundView.wantsLayer = true
    backgroundView.layer?.backgroundColor = NSColor(white: 0.18, alpha: 0.98).cgColor
    backgroundView.layer?.cornerRadius = 18
    backgroundView.layer?.masksToBounds = true
    if #available(macOS 10.15, *) {
        backgroundView.layer?.cornerCurve = .continuous
    }
    window.contentView = backgroundView

    // Visual effect view (popover material frosting)
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = .popover
    visualEffectView.blendingMode = .withinWindow
    visualEffectView.state = .active
    visualEffectView.frame = backgroundView.bounds
    visualEffectView.autoresizingMask = [.width, .height]
    backgroundView.addSubview(visualEffectView)

    // Icon
    let iconView = NSImageView()
    iconView.imageScaling = .scaleProportionallyUpOrDown
    if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
       let icon = NSImage(contentsOfFile: iconPath) {
        iconView.image = icon
    }
    iconView.frame = NSRect(x: padH, y: (windowHeight - iconSize) / 2, width: iconSize, height: iconSize)
    visualEffectView.addSubview(iconView)

    // Text area origin
    let textX = padH + iconSize + padIconText
    let textYBase = (windowHeight - textBlockHeight) / 2

    // ---- Body: Markdown rendering, dynamic multi-line height ----
    let bodyTextView = NSTextView(frame: NSRect(x: textX, y: textYBase, width: textWidth, height: bodyViewHeight))
    bodyTextView.isEditable = false
    bodyTextView.isSelectable = false
    bodyTextView.drawsBackground = false
    bodyTextView.isHorizontallyResizable = false
    bodyTextView.isVerticallyResizable = false
    bodyTextView.textContainerInset = NSSize(width: 0, height: bodyInsetY)
    bodyTextView.textContainer?.widthTracksTextView = true
    bodyTextView.textContainer?.lineFragmentPadding = 0
    bodyTextView.textContainer?.size = NSSize(width: textWidth, height: bodyViewHeight)
    bodyTextView.textStorage?.setAttributedString(bodyAttrString)

    // Title
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
    titleLabel.textColor = isDark ? .white : .black
    titleLabel.frame = NSRect(
        x: textX,
        y: textYBase + bodyViewHeight + gapSubtitleBody + codeBlockHeight + gapTitleSubtitle,
        width: textWidth,
        height: titleHeight
    )
    visualEffectView.addSubview(titleLabel)

    // Subtitle code block
    let codeBgView = NSView()
    codeBgView.wantsLayer = true
    codeBgView.layer?.backgroundColor = NSColor.nord1.cgColor
    codeBgView.layer?.cornerRadius = 4
    codeBgView.frame = NSRect(
        x: textX,
        y: textYBase + bodyViewHeight + gapSubtitleBody,
        width: codeBlockWidth,
        height: codeBlockHeight
    )
    visualEffectView.addSubview(codeBgView)

    codeLabel.frame = NSRect(x: codePadH, y: codePadV, width: codeLabel.frame.width, height: codeLabel.frame.height)
    codeBgView.addSubview(codeLabel)

    visualEffectView.addSubview(bodyTextView)

    // Close button (hover visible)
    let closeBtn = NSButton()
    closeBtn.bezelStyle = .circular
    closeBtn.title = "×"
    closeBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    closeBtn.isBordered = false
    closeBtn.wantsLayer = true
    closeBtn.layer?.backgroundColor = NSColor.clear.cgColor
    closeBtn.layer?.cornerRadius = closeSize / 2
    closeBtn.alphaValue = 0
    closeBtn.contentTintColor = .nord4

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

    window.orderFrontRegardless()
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
