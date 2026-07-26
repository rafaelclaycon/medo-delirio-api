@testable import App
import XCTVapor

final class RSSPollingServiceTests: XCTestCase {

    func testSpreakerStyleURLReturnsLastPathComponent() {
        let guid = "https://api.spreaker.com/episode/69980761"
        XCTAssertEqual(RSSPollingService.parseEpisodeId(from: guid), "69980761")
    }

    func testWordPressStyleQueryReturnsPValue() {
        let guid = "https://example.com/?p=40097"
        XCTAssertEqual(RSSPollingService.parseEpisodeId(from: guid), "40097")
    }

    func testWordPressStyleQueryAmongOtherParams() {
        let guid = "https://example.com/?utm_source=rss&p=12345"
        XCTAssertEqual(RSSPollingService.parseEpisodeId(from: guid), "12345")
    }

    func testPlainGUIDIsUsedAsIs() {
        let guid = "not-a-url-just-a-guid"
        XCTAssertEqual(RSSPollingService.parseEpisodeId(from: guid), guid)
    }

    func testURLWithNoUsablePathOrQueryFallsBackToFullGUID() {
        let guid = "https://example.com/"
        XCTAssertEqual(RSSPollingService.parseEpisodeId(from: guid), guid)
    }
}
