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

    // Layout constants
    let padTop: CGFloat = 12
    let padBottom: CGFloat = 12
    let padH: CGFloat = 16
    let padIconText: CGFloat = 12
    let iconSize: CGFloat = 40
    let closeSize: CGFloat = 16
    let closePad: CGFloat = 8

    let textWidth: CGFloat = 260
    let titleHeight: CGFloat = 22
    let gapTitleSubtitle: CGFloat = 4
    let gapSubtitleBody: CGFloat = 6

    // ---- Body: Markdown rendering + dynamic height ----
    let bodyTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: textWidth, height: 0))
    bodyTextView.isEditable = false
    bodyTextView.isSelectable = false
    bodyTextView.drawsBackground = false
    bodyTextView.isHorizontallyResizable = false
    bodyTextView.isVerticallyResizable = false
    bodyTextView.textContainerInset = NSSize(width: 0, height: 0)
    bodyTextView.textContainer?.widthTracksTextView = true
    bodyTextView.textContainer?.lineFragmentPadding = 0
    bodyTextView.textContainer?.size = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)

    let bodyFont = NSFont.systemFont(ofSize: 12)
    let bodyColor: NSColor = isDark ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.4, alpha: 1)
    let message = informativeText

    if #available(macOS 12.0, *) {
        if let data = message.data(using: .utf8),
           let attributedString = try? NSAttributedString(
               markdown: data,
               options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
           ) {
            let mutable = NSMutableAttributedString(attributedString: attributedString)
            let fullRange = NSRange(location: 0, length: mutable.length)

            // Default foreground color where not set by markdown parser
            mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                if value == nil {
                    mutable.addAttribute(.foregroundColor, value: bodyColor, range: range)
                }
            }
            // Default font where not set (preserves bold / italic from markdown)
            mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                if value == nil {
                    mutable.addAttribute(.font, value: bodyFont, range: range)
                }
            }
            // Tint inline code with nordic accent colour
            mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
                if let font = value as? NSFont {
                    let name = font.fontName.lowercased()
                    if name.contains("mono") || name.contains("menlo") || name.contains("courier") {
                        mutable.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
                    }
                }
            }
            bodyTextView.textStorage?.setAttributedString(mutable)
        } else {
            bodyTextView.string = message
            bodyTextView.textColor = bodyColor
            bodyTextView.font = bodyFont
        }
    } else {
        bodyTextView.string = message
        bodyTextView.textColor = bodyColor
        bodyTextView.font = bodyFont
    }

    // Measure body height
    let layoutManager = bodyTextView.layoutManager!
    let textContainer = bodyTextView.textContainer!
    layoutManager.ensureLayout(for: textContainer)
    var bodyHeight = layoutManager.usedRect(for: textContainer).height
    let maxBodyHeight: CGFloat = 72
    if bodyHeight > maxBodyHeight {
        bodyHeight = maxBodyHeight
    }
    if bodyHeight < 16 {
        bodyHeight = 16
    }

    // ---- Subtitle: code-block style path ----
    let codePadH: CGFloat = 6
    let codePadV: CGFloat = 3
    let codeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    let codeLabel = NSTextField(labelWithString: subtitle)
    codeLabel.font = codeFont
    codeLabel.textColor = .nord4
    codeLabel.sizeToFit()
    let codeBlockWidth = min(codeLabel.frame.width + codePadH * 2, textWidth)
    let codeBlockHeight = codeLabel.frame.height + codePadV * 2

    // ---- Overall dimensions ----
    let bodyBottomMargin: CGFloat = 4
    let textBlockHeight = titleHeight + gapTitleSubtitle + codeBlockHeight + gapSubtitleBody + bodyHeight + bodyBottomMargin
    let contentHeight = max(iconSize, textBlockHeight)
    let windowWidth = padH + iconSize + padIconText + textWidth + padH + closeSize + closePad
    let windowHeight = padTop + contentHeight + padBottom

    // ---- Window ----
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

    // Visual effect view (frosted glass, opaque to desktop)
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = .popover
    visualEffectView.blendingMode = .withinWindow
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

    // Text area origin
    let textX = padH + iconSize + padIconText
    let textYBase = (windowHeight - textBlockHeight) / 2

    // Title
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
    titleLabel.textColor = isDark ? .white : .black
    titleLabel.frame = NSRect(
        x: textX,
        y: textYBase + bodyHeight + gapSubtitleBody + codeBlockHeight + gapTitleSubtitle + bodyBottomMargin,
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
        y: textYBase + bodyHeight + gapSubtitleBody + bodyBottomMargin,
        width: codeBlockWidth,
        height: codeBlockHeight
    )
    visualEffectView.addSubview(codeBgView)

    codeLabel.frame = NSRect(x: codePadH, y: codePadV, width: codeLabel.frame.width, height: codeLabel.frame.height)
    codeBgView.addSubview(codeLabel)

    // Body (markdown rendered)
    bodyTextView.frame = NSRect(x: textX, y: textYBase + bodyBottomMargin, width: textWidth, height: bodyHeight)
    visualEffectView.addSubview(bodyTextView)

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
