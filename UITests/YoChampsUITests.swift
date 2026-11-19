import AppKit
import CoreGraphics
import XCTest

/// V0 critical flow. The app is launched with `--demo` so no provider, key or
/// network is involved: only the shell, the Ask panel and the mascot are under test.
final class YoChampsUITests: XCTestCase {
    private enum ID {
        static let askField = "askTextField"
        static let askSend = "askSendButton"
        static let newChat = "newChatButton"
        static let mascotWindow = "mascotPanel"
        static let suite = "com.yurioliveira.yochamps"
        static let hotkeyKey = "KeyboardShortcuts_ask"
        static let showHide = "Show/Hide Ask"
        static let demoQuestion = "What can you do?"
        static let demoAnswerSuffix = "streamed one word at a time"
    }

    private struct SavedDefaults {
        let hotkey: Any?
    }

    private var app: XCUIApplication!
    private var savedDefaults: SavedDefaults?
    private var launchedPID: pid_t?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // The hotkey key lives in the app's preference domain. Snapshot the
        // user's value so the tests are repeatable without destroying it.
        if let defaults = UserDefaults(suiteName: ID.suite) {
            savedDefaults = SavedDefaults(hotkey: defaults.object(forKey: ID.hotkeyKey))
            defaults.removeObject(forKey: ID.hotkeyKey)
            CFPreferencesAppSynchronize(ID.suite as CFString)
        }

        app = XCUIApplication()
        app.launchArguments = ["--demo"]
    }

    override func tearDown() {
        app?.terminate()
        if let defaults = UserDefaults(suiteName: ID.suite), let savedDefaults {
            restore(savedDefaults.hotkey, forKey: ID.hotkeyKey, in: defaults)
            CFPreferencesAppSynchronize(ID.suite as CFString)
        }
        super.tearDown()
    }

    // MARK: - Critical flow

    /// R7: the hotkey opens the Ask prompt. It must not be confused with the
    /// separately bound Show/Hide action.
    func testHotkeyOpensAsk() {
        launchApp()
        let field = app.textFields[ID.askField]
        XCTAssertTrue(field.waitForExistence(timeout: 10))

        // Close it so the hotkey is the only action that can reopen Ask.
        dismissAsk()
        XCTAssertFalse(field.exists)

        // KeyboardShortcuts' default for the `ask` name is Command-Option-K.
        app.typeKey(XCUIKeyboardKey("k"), modifierFlags: [.command, .option])

        XCTAssertTrue(field.waitForExistence(timeout: 10), "Ask did not open on Command-Option-K")
        XCTAssertTrue(app.buttons[ID.askSend].waitForExistence(timeout: 5))
    }

    /// The Ask panel must stay on screen when another app becomes active.
    /// `NSPanel.hidesOnDeactivate` defaults to true, which made the panel
    /// vanish while the app was inactive and broke the hotkey from another
    /// app. AX exposes only the menu bar for an inactive accessory app, so the
    /// assertion reads the window server list like the manual E2E did.
    func testAskStaysOnScreenWhenAnotherAppIsActive() {
        launchApp()
        let field = app.textFields[ID.askField]
        XCTAssertTrue(field.waitForExistence(timeout: 10))

        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()

        // `activate()` returns before the switch lands; wait until YoChamps is
        // no longer frontmost or the assertion could pass on the old state
        // before the app deactivates.
        let deadline = Date().addingTimeInterval(5)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ID.suite,
              Date() < deadline
        {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertNotEqual(
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            ID.suite,
            "app did not deactivate"
        )

        XCTAssertTrue(
            panelStaysOnScreen(for: 2),
            "Ask left the screen when another app became active"
        )
    }

    /// Esc dismisses the floating prompt without quitting the app.
    func testEscapeClosesAsk() {
        launchApp()
        let field = app.textFields[ID.askField]
        XCTAssertTrue(field.waitForExistence(timeout: 10))

        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        XCTAssertTrue(field.waitForNonExistence(timeout: 10), "Esc did not close Ask")
        XCTAssertTrue(isAppRunning())
    }

    /// The mascot is embedded in the Ask window, so Show/Hide toggles that
    /// window (and the image inside it) while the process keeps running.
    func testShowHideKeepsProcessAlive() {
        launchApp()

        let mascot = app.images[ID.mascotWindow]
        XCTAssertTrue(mascot.waitForExistence(timeout: 10))
        XCTAssertTrue(isAppRunning())

        clickShowHide()
        XCTAssertTrue(mascot.waitForNonExistence(timeout: 10), "Show/Hide did not hide Ask")
        XCTAssertTrue(isAppRunning(), "Hiding Ask must not terminate the process")

        clickShowHide()
        XCTAssertTrue(mascot.waitForExistence(timeout: 10), "Show/Hide did not show Ask again")
        XCTAssertTrue(isAppRunning())
    }

    /// The compact "+" button clears the chat transcript.
    func testNewChatButtonClearsTranscript() {
        launchApp()
        XCTAssertNotNil(waitForAnswer(timeout: 15), "demo answer did not appear")

        let newChat = app.buttons[ID.newChat]
        XCTAssertTrue(newChat.waitForExistence(timeout: 5), "New Chat (+) button missing")
        newChat.click()

        XCTAssertTrue(waitForAnswerGone(timeout: 5), "New Chat did not clear the transcript")
    }

    /// Command-N is the advertised shortcut for the same action.
    func testCommandNStartsNewChat() {
        launchApp()
        XCTAssertNotNil(waitForAnswer(timeout: 15), "demo answer did not appear")

        app.typeKey(XCUIKeyboardKey("n"), modifierFlags: [.command])

        XCTAssertTrue(waitForAnswerGone(timeout: 5), "Command-N did not clear the transcript")
    }

    /// The mascot is embedded in the Ask window header, with the answer in a
    /// separate transcript below. Its avatar is a fixed 56pt square.
    func testEmbeddedMascotDoesNotOverlapLongAnswer() {
        launchApp()

        let mascot = app.images[ID.mascotWindow]
        XCTAssertTrue(mascot.waitForExistence(timeout: 10))

        // `--demo` pre-asks the fixture question through showDemo(); wait for
        // that stream to settle before typing again.
        XCTAssertNotNil(waitForAnswer(timeout: 15), "demo answer did not appear")
        // "Cancel" is present only while a turn is busy; wait for it to go so
        // the previous turn has settled and the send button accepts the next
        // question (the field itself is always enabled).
        XCTAssertTrue(app.buttons["Cancel"].waitForNonExistence(timeout: 10), "demo stream did not settle")

        let field = app.textFields[ID.askField]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.click()
        field.typeText(ID.demoQuestion)
        app.buttons[ID.askSend].click()

        // The send resets the answer; wait for that before waiting for the
        // reply so the captured element is the freshly streamed one.
        let clearedDeadline = Date().addingTimeInterval(5)
        while Date() < clearedDeadline, currentAnswer() != nil {
            Thread.sleep(forTimeInterval: 0.05)
        }

        guard let answer = waitForAnswer(timeout: 15) else {
            XCTFail("long answer did not appear")
            return
        }

        let mascotFrame = mascot.frame
        let answerFrame = answer.frame
        XCTAssertFalse(mascotFrame.intersects(answerFrame), "mascot overlaps the answer text")
        // AX reports the image view within a couple of points of the 56pt
        // avatar frame; allow that measurement slack but never a shrink.
        XCTAssertEqual(mascotFrame.width, 56, accuracy: 2, "mascot avatar shrank below 56pt")
    }

    // MARK: - New Ask layout and text behavior

    /// Header order: the animated avatar sits on the left, new chat on the right.
    func testHeaderMascotIsLeftOfNewChat() {
        launchApp()

        let mascot = app.images[ID.mascotWindow]
        XCTAssertTrue(mascot.waitForExistence(timeout: 10), "mascot avatar missing")
        let newChat = app.buttons[ID.newChat]
        XCTAssertTrue(newChat.waitForExistence(timeout: 5), "new chat button missing")

        XCTAssertLessThan(
            mascot.frame.minX,
            newChat.frame.minX,
            "avatar must sit left of the new-chat button"
        )
    }

    /// Markdown markers are styled, never shown literally.
    func testAnswerHasNoLiteralMarkdown() {
        launchApp()

        guard let answer = waitForAnswer(timeout: 15) else {
            XCTFail("demo answer did not appear")
            return
        }
        let text = (answer.value as? String) ?? answer.label
        XCTAssertFalse(text.contains("**"), "literal bold marker in: \(text)")
        XCTAssertFalse(text.contains("~~"), "literal strike marker in: \(text)")
    }

    /// Selecting answer text copies it on mouse-up.
    func testCopyOnSelect() {
        launchApp()

        guard let answer = waitForAnswer(timeout: 15) else {
            XCTFail("demo answer did not appear")
            return
        }
        XCTAssertTrue(app.buttons["Cancel"].waitForNonExistence(timeout: 10), "demo stream did not settle")

        NSPasteboard.general.clearContents()
        // Drag across the first line of the answer: a real selection gesture
        // whose mouse-up must copy. A double-click at the element centre can
        // land past short text and select nothing.
        let start = answer.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.08))
        let end = answer.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.08))
        start.press(forDuration: 0.1, thenDragTo: end)

        let deadline = Date().addingTimeInterval(5)
        var copied = ""
        while Date() < deadline {
            copied = NSPasteboard.general.string(forType: .string) ?? ""
            if !copied.isEmpty {
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        XCTAssertFalse(
            copied.isEmpty,
            "mouse selection did not reach the pasteboard (frame=\(answer.frame), hittable=\(answer.isHittable))"
        )
        let displayed = (answer.value as? String) ?? answer.label
        XCTAssertTrue(
            displayed.contains(copied.trimmingCharacters(in: .whitespacesAndNewlines)),
            "copied text \(copied) is not part of the answer"
        )
    }

    // MARK: - Helpers

    private func launchApp() {
        let before = runningPIDs()
        app.launch()
        // LSUIElement runs as an accessory, so it never reports RunningForeground.
        let deadline = Date().addingTimeInterval(10)
        while app.state == .notRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertNotEqual(app.state, .notRunning, "app did not launch")
        // The launched instance is the PID that appeared after launch, so a
        // stray installed copy cannot satisfy the window-server assertion.
        launchedPID = runningPIDs().subtracting(before).first
        // An inactive accessory app exposes only its menu bar to the AX tree.
        // Activating it is required before its panels become queryable.
        app.activate()
        // Activation is a request: another app can take focus while we wait,
        // so re-issue it until the app is frontmost before querying AX.
        let activationDeadline = Date().addingTimeInterval(10)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != ID.suite,
              Date() < activationDeadline
        {
            app.activate()
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            ID.suite,
            "app did not become frontmost"
        )
    }

    private func runningPIDs() -> Set<pid_t> {
        Set(
            NSRunningApplication
                .runningApplications(withBundleIdentifier: ID.suite)
                .map(\.processIdentifier)
        )
    }

    /// SwiftUI exposes `Text` through the AX `value`; the Markdown answer is an
    /// `NSTextView`, so it arrives under `textViews` instead. Poll both and
    /// prefer the last match, so the newest turn wins.
    private func currentAnswer() -> XCUIElement? {
        let candidates = app.textViews.allElementsBoundByIndex
            + app.staticTexts.allElementsBoundByIndex
        return candidates.last {
            ($0.value as? String)?.contains(ID.demoAnswerSuffix) == true
        }
    }

    private func waitForAnswer(timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let answer = currentAnswer() {
                return answer
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }

    private func waitForAnswerGone(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if currentAnswer() == nil {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private func dismissAsk() {
        let field = app.textFields[ID.askField]
        guard field.exists else { return }
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        _ = field.waitForNonExistence(timeout: 5)
    }

    private func clickShowHide() {
        // Only one status item is exposed to AX here, and macOS can report it
        // as non-hittable for a beat after activation. Poll instead of taking
        // firstMatch on a single sample.
        let deadline = Date().addingTimeInterval(10)
        var statusItem: XCUIElement?
        while Date() < deadline {
            let candidates = app.statusItems.allElementsBoundByIndex
            statusItem = candidates.first {
                $0.isHittable && $0.title.localizedCaseInsensitiveContains("Champ")
            } ?? candidates.first { $0.isHittable }
            if statusItem != nil {
                break
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        guard let statusItem else {
            XCTFail("No hittable status item found")
            return
        }
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "Status item not found")
        statusItem.click()

        let item = app.menuItems[ID.showHide]
        XCTAssertTrue(item.waitForExistence(timeout: 10), "Show/Hide menu item not found")
        item.click()
    }

    private func isAppRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: ID.suite).isEmpty
    }

    /// True only when the launched instance keeps a floating-level window in
    /// the window server's on-screen list for the whole interval. A late hide
    /// fails on the first sample that misses, so the check cannot pass on the
    /// pre-deactivation state. Screen Recording is not needed: owner PID and
    /// layer are available without it.
    private func panelStaysOnScreen(for duration: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(duration)
        repeat {
            if !onScreenPanelExists() {
                return false
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return true
    }

    private func onScreenPanelExists() -> Bool {
        guard let launchedPID else { return false }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: Any]] ?? []
        return windows.contains { window in
            guard
                let owner = window[kCGWindowOwnerPID as String] as? Int,
                let layer = window[kCGWindowLayer as String] as? Int
            else {
                return false
            }
            return pid_t(owner) == launchedPID && layer == NSWindow.Level.floating.rawValue
        }
    }

    private func restore(_ value: Any?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
