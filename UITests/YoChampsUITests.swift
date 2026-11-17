import AppKit
import XCTest

/// M3 critical flow. The app is launched with `--demo` so no provider, key or
/// network is involved: only the shell, the panels and the mascot are under test.
final class YoChampsUITests: XCTestCase {
    private enum ID {
        static let askField = "askTextField"
        static let askSend = "askSendButton"
        static let mascotWindow = "mascotPanel"
        static let suite = "com.yurioliveira.yochamps"
        static let originKey = "mascotPanelOrigin"
        static let hotkeyKey = "KeyboardShortcuts_ask"
        static let showHide = "Show/Hide Champ"
    }

    private struct SavedDefaults {
        let origin: Any?
        let hotkey: Any?
    }

    private var app: XCUIApplication!
    private var savedDefaults: SavedDefaults?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        // Both keys live in the app's preference domain. Snapshot the user's
        // values so the tests are repeatable without destroying customizations.
        if let defaults = UserDefaults(suiteName: ID.suite) {
            savedDefaults = SavedDefaults(
                origin: defaults.object(forKey: ID.originKey),
                hotkey: defaults.object(forKey: ID.hotkeyKey)
            )
            defaults.removeObject(forKey: ID.originKey)
            defaults.removeObject(forKey: ID.hotkeyKey)
            CFPreferencesAppSynchronize(ID.suite as CFString)
        }

        app = XCUIApplication()
        app.launchArguments = ["--demo"]
    }

    override func tearDown() {
        app?.terminate()
        if let defaults = UserDefaults(suiteName: ID.suite), let savedDefaults {
            restore(savedDefaults.origin, forKey: ID.originKey, in: defaults)
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

        // KeyboardShortcuts' default for the `ask` name is Command-Option-Y.
        app.typeKey(XCUIKeyboardKey("y"), modifierFlags: [.command, .option])

        XCTAssertTrue(field.waitForExistence(timeout: 10), "Ask did not open on Command-Option-Y")
        XCTAssertTrue(app.buttons[ID.askSend].waitForExistence(timeout: 5))
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

    /// Show/Hide toggles Champ's window while the process keeps running.
    func testShowHideKeepsProcessAlive() {
        launchApp()
        dismissAsk()

        let mascot = app.windows[ID.mascotWindow]
        XCTAssertTrue(mascot.waitForExistence(timeout: 10))
        XCTAssertTrue(isAppRunning())

        clickShowHide()
        XCTAssertTrue(mascot.waitForNonExistence(timeout: 10), "Show/Hide did not hide Champ")
        XCTAssertTrue(isAppRunning(), "Hiding Champ must not terminate the process")

        clickShowHide()
        XCTAssertTrue(mascot.waitForExistence(timeout: 10), "Show/Hide did not show Champ again")
        XCTAssertTrue(isAppRunning())
    }

    /// Dragging persists the origin; a fresh process restores it.
    func testDragThenRelaunchRestoresPosition() {
        launchApp()
        dismissAsk()

        let mascot = app.windows[ID.mascotWindow]
        XCTAssertTrue(mascot.waitForExistence(timeout: 10))

        let initial = mascot.frame.origin
        let start = mascot.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -180, dy: 90))
        start.press(forDuration: 0.2, thenDragTo: end)

        var dragged = mascot.frame.origin
        for _ in 0 ..< 20
            where abs(dragged.x - initial.x) < 20 && abs(dragged.y - initial.y) < 20
        {
            Thread.sleep(forTimeInterval: 0.1)
            dragged = mascot.frame.origin
        }
        XCTAssertNotEqual(dragged, initial, "Drag did not move Champ")

        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))

        launchApp()
        let restored = app.windows[ID.mascotWindow]
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        let origin = restored.frame.origin
        XCTAssertEqual(origin.x, dragged.x, accuracy: 2)
        XCTAssertEqual(origin.y, dragged.y, accuracy: 2)
    }

    // MARK: - Helpers

    private func launchApp() {
        app.launch()
        // LSUIElement runs as an accessory, so it never reports RunningForeground.
        let deadline = Date().addingTimeInterval(10)
        while app.state == .notRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertNotEqual(app.state, .notRunning, "app did not launch")
        // An inactive accessory app exposes only its menu bar to the AX tree.
        // Activating it is required before its panels become queryable.
        app.activate()
    }

    private func dismissAsk() {
        let field = app.textFields[ID.askField]
        guard field.exists else { return }
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        _ = field.waitForNonExistence(timeout: 5)
    }

    private func clickShowHide() {
        // SwiftUI MenuBarExtra is exposed as a StatusItem with an internal AX
        // title, not as a MenuBarItem named after the app.
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "Status item not found")
        statusItem.click()

        let item = app.menuItems[ID.showHide]
        XCTAssertTrue(item.waitForExistence(timeout: 10), "Show/Hide menu item not found")
        item.click()
    }

    private func isAppRunning() -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.yurioliveira.yochamps"
        ).isEmpty
    }

    private func restore(_ value: Any?, forKey key: String, in defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
