@testable import App
import XCTVapor
import Fluent
import Foundation

final class ReactionStatsTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        TestEnvironment.configurePasswords()
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    @discardableResult
    private func createReaction(_ title: String, position: Int = 1) async throws -> UUID {
        let reaction = Reaction(
            title: title,
            position: position,
            image: "https://example.com/\(position).jpg",
            lastUpdate: "2026-10-01T10:00:00.000Z",
            attributionText: nil,
            attributionURL: "https://example.com/autor"
        )
        try await reaction.save(on: app.db)
        return try XCTUnwrap(reaction.id)
    }

    private func addViews(_ destinationScreen: String, count: Int, daysAgo: Double = 0) async throws {
        let dateTime = Date().addingTimeInterval(-daysAgo * 24 * 60 * 60).iso8601withFractionalSeconds
        for _ in 0..<count {
            try await UsageMetric(
                customInstallId: "install-1",
                originatingScreen: "ReactionsTab",
                destinationScreen: destinationScreen,
                systemName: "iOS",
                isiOSAppOnMac: false,
                appVersion: "13.4",
                dateTime: dateTime,
                currentTimeZone: "BRT"
            ).create(on: app.db)
        }
    }

    // MARK: - top-3-reactions

    func testTop3ReturnsTodaysMostViewedReactionsAsJSON() async throws {
        let hmm = try await createReaction("Hmm", position: 4)
        let rindo = try await createReaction("Rindo", position: 2)
        let chocado = try await createReaction("Chocado", position: 3)
        try await createReaction("Bravo", position: 5)
        try await addViews("didViewReaction(Hmm)", count: 3)
        try await addViews("didViewReaction(Rindo)", count: 2)
        try await addViews("didViewReaction(Chocado)", count: 1)
        // Only today counts, and the tab itself isn't a reaction.
        try await addViews("didViewReaction(Bravo)", count: 9, daysAgo: 2)
        try await addViews("didViewReactionsTab", count: 9)

        try await app.test(.GET, "api/v4/top-3-reactions") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
            XCTAssertEqual(list.map { $0["id"] as? String }, [hmm.uuidString, rindo.uuidString, chocado.uuidString])
            let json = try XCTUnwrap(list.first)
            XCTAssertEqual(Set(json.keys), ["id", "title", "position", "image", "lastUpdate", "attributionText", "attributionURL"])
            XCTAssertEqual(json["title"] as? String, "Hmm")
            XCTAssertEqual(json["position"] as? Int, 4)
            XCTAssertEqual(json["image"] as? String, "https://example.com/4.jpg")
            XCTAssertEqual(json["lastUpdate"] as? String, "2026-10-01T10:00:00.000Z")
            XCTAssertTrue(json["attributionText"] is NSNull)
            XCTAssertEqual(json["attributionURL"] as? String, "https://example.com/autor")
        }
    }

    /// Views are matched to reactions by title after stripping the wrapper and every
    /// ")" in it, so a view of a deleted reaction, or of a title with its own
    /// parentheses, comes back as an empty reaction.
    func testTop3ReturnsAnEmptyReactionForViewsThatMatchNoReaction() async throws {
        try await createReaction("Hmm (sério)")
        try await addViews("didViewReaction(Hmm (sério))", count: 2)

        try await app.test(.GET, "api/v4/top-3-reactions") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let reactions = try res.content.decode([Reaction].self)
            XCTAssertEqual(reactions.count, 1)
            XCTAssertNil(reactions.first?.id)
            XCTAssertEqual(reactions.first?.title, "")
            XCTAssertEqual(reactions.first?.position, 0)
        }
    }

    func testTop3IsEmptyWithoutViewsToday() async throws {
        try await createReaction("Hmm")
        try await addViews("didViewReaction(Hmm)", count: 2, daysAgo: 2)

        try await app.test(.GET, "api/v4/top-3-reactions") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([Reaction].self).count, 0)
        }
    }

    // MARK: - reaction-popularity-stats

    func testPopularityReturnsTheTopReactionForTodayTheLastWeekAndAllTime() async throws {
        let hoje = try await createReaction("Hoje", position: 1)
        let semana = try await createReaction("Semana", position: 2)
        let sempre = try await createReaction("Sempre", position: 3)
        try await addViews("didViewReaction(Hoje)", count: 2)
        try await addViews("didViewReaction(Semana)", count: 3, daysAgo: 3)
        try await addViews("didViewReaction(Sempre)", count: 10, daysAgo: 60)
        try await addViews("didViewReactionsTab", count: 50)

        try await app.test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
            XCTAssertEqual(list.map { $0["position"] as? String }, ["1", "2", "3"])
            XCTAssertEqual(list.map { $0["description"] as? String }, ["hoje", "última semana", "todos os tempos"])
            XCTAssertEqual(list.map { ($0["reaction"] as? [String: Any])?["id"] as? String }, [hoje.uuidString, semana.uuidString, sempre.uuidString])
            let first = try XCTUnwrap(list.first)
            XCTAssertEqual(Set(first.keys), ["position", "reaction", "description"])
            let reaction = try XCTUnwrap(first["reaction"] as? [String: Any])
            XCTAssertEqual(reaction["title"] as? String, "Hoje")
            XCTAssertEqual(reaction["position"] as? Int, 1)
        }
    }

    /// Each period only appears when it had any views.
    func testPopularityLeavesOutPeriodsWithoutViews() async throws {
        let sempre = try await createReaction("Sempre")
        try await addViews("didViewReaction(Sempre)", count: 1, daysAgo: 60)

        try await app.test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
            let stats = try res.content.decode([TopChartReaction].self)
            XCTAssertEqual(stats.map(\.position), ["3"])
            XCTAssertEqual(stats.first?.reaction.id, sempre)
        }

        try await UsageMetric.query(on: app.db).delete()
        try await app.test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([TopChartReaction].self).count, 0)
        }
    }
}
