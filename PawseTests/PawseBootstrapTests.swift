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

    func testBuildInfoReadsVersionAndBuildMetadata() {
        let buildInfo = PawseBuildInfo(infoDictionary: [
            "CFBundleShortVersionString": "0.2.0",
            "CFBundleVersion": 3,
        ])

        XCTAssertEqual(buildInfo.version, "0.2.0")
        XCTAssertEqual(buildInfo.build, "3")
    }

    func testBuildInfoUsesPlaceholderForMissingOrEmptyMetadata() {
        let buildInfo = PawseBuildInfo(infoDictionary: [
            "CFBundleShortVersionString": "  ",
        ])

        XCTAssertEqual(buildInfo.version, PawseBuildInfo.unavailableValue)
        XCTAssertEqual(buildInfo.build, PawseBuildInfo.unavailableValue)
    }

    func testCanonicalProjectLinks() {
        XCTAssertEqual(PawseLinks.author.absoluteString, "https://yorukot.me")
        XCTAssertEqual(PawseLinks.donate.absoluteString, "https://yorukot.me/donate")
        XCTAssertEqual(
            PawseLinks.github.absoluteString,
            "https://github.com/yorukot/pawse"
        )
    }

    func testAboutIsTheLastPersistedWindowSection() {
        XCTAssertEqual(PawseWindowSection.allCases.last, .about)
        XCTAssertEqual(PawseWindowSection.about.rawValue, "about")
        XCTAssertEqual(PawseWindowSection.storageKey, "pawseWindowSection")
    }
}
