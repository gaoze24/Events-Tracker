//
//  Events_TrackerUITestsLaunchTests.swift
//  Events TrackerUITests
//
//  Created by Eddie Gao on 24/3/25.
//

import XCTest

private let uiTestingLaunchArgument = "--ui-testing"

final class Events_TrackerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append(uiTestingLaunchArgument)
        app.launch()

        XCTAssertTrue(app.staticTexts["Dashboard"].waitForExistence(timeout: 5))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
