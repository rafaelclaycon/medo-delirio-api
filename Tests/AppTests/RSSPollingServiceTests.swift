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

    // MARK: - Feed parsing

    func testParseFeedReturnsLatestEpisodeAndAllItems() throws {
        let snapshot = try RSSPollingService.parseFeed(Self.feed(itemCount: 6))

        XCTAssertEqual(snapshot.latest.guid, "https://api.spreaker.com/episode/1006")
        XCTAssertEqual(snapshot.latest.title, "II - 2026.6 - Episódio 6")
        XCTAssertEqual(snapshot.latest.imageURL, "https://images.example.com/1006.jpg")
        XCTAssertEqual(snapshot.episodes.map(\.guid).last, "https://api.spreaker.com/episode/1001")
        XCTAssertEqual(snapshot.episodes.count, 6)
    }

    func testParseFeedRejectsFeedWithTooFewItems() {
        XCTAssertThrowsError(try RSSPollingService.parseFeed(Self.feed(itemCount: 2))) { error in
            guard case .tooFewItems(2) = error as? RSSPollingService.FeedError else {
                return XCTFail("Expected tooFewItems(2), got \(error)")
            }
        }
    }

    func testParseFeedRejectsLatestItemWithoutGUID() {
        let data = Self.feed(itemCount: 5, latestHasGUID: false)
        XCTAssertThrowsError(try RSSPollingService.parseFeed(data)) { error in
            guard case .missingLatestGUID = error as? RSSPollingService.FeedError else {
                return XCTFail("Expected missingLatestGUID, got \(error)")
            }
        }
    }

    func testParseFeedRejectsInvalidXML() {
        XCTAssertThrowsError(try RSSPollingService.parseFeed(Data("<html>Bad Gateway".utf8))) { error in
            guard case .parse = error as? RSSPollingService.FeedError else {
                return XCTFail("Expected parse, got \(error)")
            }
        }
    }

    /// A feed shaped like Spreaker's, newest episode first.
    private static func feed(itemCount: Int, latestHasGUID: Bool = true) -> Data {
        let items = (1...itemCount).reversed().map { number in
            let id = 1000 + number
            let guid = number == itemCount && !latestHasGUID
                ? ""
                : #"<guid isPermaLink="false">https://api.spreaker.com/episode/\#(id)</guid>"#
            return """
            <item><title>II - 2026.\(number) - Episódio \(number)</title>\(guid)\
            <pubDate>Fri, 2\(number) Oct 2026 22:02:54 +0000</pubDate>\
            <itunes:image href="https://images.example.com/\(id).jpg"/></item>
            """
        }
        return Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" version="2.0"><channel>
        <title>Medo e Delírio em Brasília</title>
        \(items.joined(separator: "\n"))
        </channel></rss>
        """.utf8)
    }
}
