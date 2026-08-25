import XCTest
@testable import Breather

final class BreatherBootstrapTests: XCTestCase {
    func testApplicationName() {
        XCTAssertEqual("Breather", "Breather")
    }

    func testApplicationIsConfiguredToAppearInDock() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, false)
    }
}
