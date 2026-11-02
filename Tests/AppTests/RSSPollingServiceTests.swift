@testable import App
import Testing
import VaporTesting
import Foundation

struct RSSPollingServiceTests {

    @Test func `Spreaker style URL returns last path component`() {
        let guid = "https://api.spreaker.com/episode/69980761"
        #expect(RSSPollingService.parseEpisodeId(from: guid) == "69980761")
    }

    @Test func `WordPress style query returns p value`() {
        let guid = "https://example.com/?p=40097"
        #expect(RSSPollingService.parseEpisodeId(from: guid) == "40097")
    }

    @Test func `WordPress style query among other params`() {
        let guid = "https://example.com/?utm_source=rss&p=12345"
        #expect(RSSPollingService.parseEpisodeId(from: guid) == "12345")
    }

    @Test func `Plain GUID is used as is`() {
        let guid = "not-a-url-just-a-guid"
        #expect(RSSPollingService.parseEpisodeId(from: guid) == guid)
    }

    @Test func `URL with no usable path or query falls back to full GUID`() {
        let guid = "https://example.com/"
        #expect(RSSPollingService.parseEpisodeId(from: guid) == guid)
    }

    // MARK: - Feed parsing

    @Test func `Parse feed returns latest episode and all items`() throws {
        let snapshot = try RSSPollingService.parseFeed(Self.feed(itemCount: 6))

        #expect(snapshot.latest.guid == "https://api.spreaker.com/episode/1006")
        #expect(snapshot.latest.title == "II - 2026.6 - Episódio 6")
        #expect(snapshot.latest.imageURL == "https://images.example.com/1006.jpg")
        #expect(snapshot.episodes.map(\.guid).last == "https://api.spreaker.com/episode/1001")
        #expect(snapshot.episodes.count == 6)
    }

    @Test func `Parse feed rejects feed with too few items`() {
        let error = #expect(throws: RSSPollingService.FeedError.self) {
            try RSSPollingService.parseFeed(Self.feed(itemCount: 2))
        }
        guard case .tooFewItems(2) = error else {
            Issue.record("Expected tooFewItems(2), got \(String(describing: error))")
            return
        }
    }

    @Test func `Parse feed rejects latest item without GUID`() {
        let data = Self.feed(itemCount: 5, latestHasGUID: false)
        let error = #expect(throws: RSSPollingService.FeedError.self) {
            try RSSPollingService.parseFeed(data)
        }
        guard case .missingLatestGUID = error else {
            Issue.record("Expected missingLatestGUID, got \(String(describing: error))")
            return
        }
    }

    @Test func `Parse feed rejects invalid XML`() {
        let error = #expect(throws: RSSPollingService.FeedError.self) {
            try RSSPollingService.parseFeed(Data("<html>Bad Gateway".utf8))
        }
        guard case .parse = error else {
            Issue.record("Expected parse, got \(String(describing: error))")
            return
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
