import XCTest

final class OnboardingUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testOnboardingExposesEnablementPathAndTryoutField() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.staticTexts["水杉输入法"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["openKeyboardSettingsButton"].exists)

    let schemePicker = app.segmentedControls["inputSchemePicker"]
    XCTAssertTrue(schemePicker.exists)
    XCTAssertTrue(schemePicker.buttons["全拼"].exists)
    XCTAssertTrue(schemePicker.buttons["小鹤双拼"].exists)

    let outputPicker = app.segmentedControls["chineseOutputPicker"]
    XCTAssertTrue(outputPicker.exists)
    XCTAssertTrue(outputPicker.buttons["简体"].exists)
    XCTAssertTrue(outputPicker.buttons["繁体"].exists)

    let tryoutField = app.textFields["keyboardTryoutField"]
    XCTAssertTrue(tryoutField.waitForExistence(timeout: 10))
    // The first tap can be lost while XCTest is establishing the automation session on a fresh
    // simulator. Retap a bounded number of times, and only type after the field reports focus;
    // otherwise typeText fails with "Neither element nor any descendant has keyboard focus".
    var hasFocus = false
    for _ in 0..<3 {
      tryoutField.tap()
      let focused = expectation(
        for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: tryoutField)
      if XCTWaiter().wait(for: [focused], timeout: 4) == .completed {
        hasFocus = true
        break
      }
    }
    XCTAssertTrue(hasFocus, "The tryout field did not receive keyboard focus after tapping")
    tryoutField.typeText("test")
    XCTAssertEqual(tryoutField.value as? String, "test")

    // The field had no way to put the keyboard away without leaving the app.
    let dismissButton = app.buttons["dismissKeyboardButton"]
    XCTAssertTrue(dismissButton.waitForExistence(timeout: 5))
    dismissButton.tap()
    let unfocused = expectation(
      for: NSPredicate(format: "hasKeyboardFocus == false"), evaluatedWith: tryoutField)
    wait(for: [unfocused], timeout: 10)
    XCTAssertEqual(tryoutField.value as? String, "test")
  }
}
