import XCTest

final class ClavueUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper

    private var newChatButton: XCUIElement {
        app.buttons.matching(identifier: "newChatButton").firstMatch
    }

    // MARK: - Window & Layout

    func testAppLaunches() {
        XCTAssertTrue(app.windows.count >= 1, "App should have at least one window")
    }

    func testNewChatButtonExists() {
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5), "New Chat button should exist")
    }

    func testNewChatButtonIsTappable() {
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 5))
        XCTAssertTrue(newChatButton.isEnabled, "New Chat button should be enabled")
        newChatButton.click()
        // Should not crash
    }

    // MARK: - Sidebar

    func testSidebarShowsProjectSection() {
        let projectHeader = app.staticTexts["Project"]
        XCTAssertTrue(projectHeader.waitForExistence(timeout: 5),
                      "Sidebar should show Project section")
    }

    func testChooseFolderButtonExists() {
        let btn = app.buttons["chooseFolderButton"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5),
                      "Choose Folder button should exist in sidebar")
    }

    func testSidebarShowsCLISection() {
        let cliHeader = app.staticTexts["Claude CLI"]
        XCTAssertTrue(cliHeader.waitForExistence(timeout: 5),
                      "Sidebar should show Claude CLI section")
    }

    func testSidebarShowsCLIStatus() {
        // Should show either the path or "Not found"
        let found = app.staticTexts.matching(NSPredicate(
            format: "value CONTAINS[c] 'claude' OR value CONTAINS[c] 'Not found'"
        ))
        XCTAssertTrue(found.count > 0 || app.staticTexts["Not found"].exists,
                      "Should show CLI status")
    }

    // MARK: - Empty State

    func testEmptyStateShowsClaudeCode() {
        let title = app.staticTexts["Claude Code"]
        XCTAssertTrue(title.waitForExistence(timeout: 5),
                      "Empty state should show 'Claude Code' title")
    }

    func testEmptyStateShowsGuidance() {
        // Should show one of the guidance texts
        let selectFolder = app.staticTexts["Select a project folder in the sidebar to get started."]
        let typePrompt = app.staticTexts["Type a prompt below to start coding."]

        let hasGuidance = selectFolder.waitForExistence(timeout: 5) || typePrompt.exists
        XCTAssertTrue(hasGuidance, "Empty state should show guidance text")
    }

    // MARK: - Input Bar

    func testInputBarShowsDisabledStateOrInput() {
        let input = app.textFields["messageInput"]
        let cliNotFound = app.otherElements["cliNotFound"]
        let noFolder = app.otherElements["noFolderSelected"]

        let timeout: TimeInterval = 5
        let hasInput = input.waitForExistence(timeout: timeout)
        let hasDisabled = cliNotFound.exists || noFolder.exists

        XCTAssertTrue(hasInput || hasDisabled,
                      "Should show either input field or disabled state")
    }

    func testSendButtonExistsWhenInputVisible() {
        let input = app.textFields["messageInput"]
        guard input.waitForExistence(timeout: 5) else {
            // Input not visible (CLI not found or no project), skip
            return
        }
        let sendBtn = app.buttons["sendButton"]
        XCTAssertTrue(sendBtn.exists, "Send button should exist when input is visible")
    }

    func testSendButtonDisabledWhenEmpty() {
        let input = app.textFields["messageInput"]
        guard input.waitForExistence(timeout: 5) else { return }

        let sendBtn = app.buttons["sendButton"]
        XCTAssertTrue(sendBtn.exists)
        XCTAssertFalse(sendBtn.isEnabled,
                       "Send button should be disabled when input is empty")
    }

    func testSendButtonEnabledAfterTyping() {
        let input = app.textFields["messageInput"]
        guard input.waitForExistence(timeout: 5) else { return }

        input.click()
        input.typeText("Hello")

        let sendBtn = app.buttons["sendButton"]
        XCTAssertTrue(sendBtn.isEnabled,
                      "Send button should be enabled after typing text")
    }

    // MARK: - New Chat Flow

    func testNewChatClearsMessages() {
        guard newChatButton.waitForExistence(timeout: 5) else { return }
        newChatButton.click()

        // After new chat, empty state should appear
        let title = app.staticTexts["Claude Code"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "New Chat should show empty state")
    }

    // MARK: - Activity Bar Not Visible Initially

    func testActivityBarNotVisibleInitially() {
        let activity = app.otherElements["activityBar"]
        // Activity bar should not be visible when not processing
        XCTAssertFalse(activity.exists,
                       "Activity bar should not be visible when not processing")
    }

    // MARK: - Error Banner Not Visible Initially

    func testErrorBannerNotVisibleInitially() {
        let error = app.otherElements["errorBanner"]
        XCTAssertFalse(error.exists,
                       "Error banner should not be visible initially")
    }

    // MARK: - Multiple New Chat Clicks

    func testMultipleNewChatClicksDoNotCrash() {
        guard newChatButton.waitForExistence(timeout: 5) else { return }

        for _ in 0..<5 {
            newChatButton.click()
        }

        // App should still be responsive
        XCTAssertTrue(newChatButton.isEnabled)
    }
}
