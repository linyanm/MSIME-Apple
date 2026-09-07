import XCTest
import UIKit

@MainActor
final class NineKeyKeyboardTests: XCTestCase {
  private func descendants(_ view: UIView) -> [UIView] {
    [view] + view.subviews.flatMap { descendants($0) }
  }

  private func button(_ identifier: String, in controller: KeyboardViewController) throws -> UIButton {
    try XCTUnwrap(descendants(controller.view).first {
      $0.accessibilityIdentifier == identifier
    } as? UIButton)
  }

  func testNineKeyInputAndLayoutSwitches() throws {
    let previous = InputSchemePreference.scheme
    InputSchemePreference.scheme = .nineKey
    defer { InputSchemePreference.scheme = previous }
    let controller = KeyboardViewController()
    controller.loadViewIfNeeded()
    controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 216)
    controller.view.layoutIfNeeded()

    let nine = try button("nineKey6", in: controller)
    XCTAssertFalse(try XCTUnwrap(nine.superview).isHidden)
    XCTAssertEqual(try button("schemeButton", in: controller).menu?.children.count, 3)
    for digit in "64426" {
      try button("nineKey\(digit)", in: controller).sendActions(for: .primaryActionTriggered)
    }
    XCTAssertTrue(try XCTUnwrap(button("candidate-1", in: controller).configuration?.title).contains("你好"))
    try button("nineKeySpelling_ni", in: controller).sendActions(for: .primaryActionTriggered)
    XCTAssertTrue(try XCTUnwrap(button("candidate-1", in: controller).configuration?.title).contains("你好"))
    controller.view.layoutIfNeeded()
    XCTAssertGreaterThanOrEqual(nine.bounds.height, 30)
    XCTAssertGreaterThan(nine.bounds.width, 60)
    let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { context in
      controller.view.layer.render(in: context.cgContext)
    }
    let attachment = XCTAttachment(image: image)
    attachment.name = "Nine-key pinyin keyboard"
    attachment.lifetime = .keepAlways
    add(attachment)

    try button("layoutToggleButton", in: controller).sendActions(for: .primaryActionTriggered)
    XCTAssertTrue(try XCTUnwrap(nine.superview).isHidden)
    try button("layoutToggleButton", in: controller).sendActions(for: .primaryActionTriggered)
    XCTAssertFalse(try XCTUnwrap(nine.superview).isHidden)
    try button("languageModeButton", in: controller).sendActions(for: .primaryActionTriggered)
    XCTAssertTrue(try XCTUnwrap(nine.superview).isHidden)
    try button("languageModeButton", in: controller).sendActions(for: .primaryActionTriggered)
    XCTAssertFalse(try XCTUnwrap(nine.superview).isHidden)
    XCTAssertEqual(try button("schemeButton", in: controller).accessibilityValue, "全拼 9 键")

    InputSchemePreference.scheme = .shuangpin
    controller.viewWillAppear(false)
    XCTAssertTrue(try XCTUnwrap(nine.superview).isHidden)
    XCTAssertEqual(try button("schemeButton", in: controller).accessibilityValue, "小鹤双拼")
  }
}
