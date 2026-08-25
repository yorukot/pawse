import XCTest
@testable import Breather

final class PawseBootstrapTests: XCTestCase {
    func testApplicationName() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            "Pawse"
        )
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
            "Pawse"
        )
    }

}
