@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct ReactionStatsTests {

    @discardableResult
    private func createReaction(_ title: String, position: Int = 1, on app: Application) async throws -> UUID {
        let reaction = Reaction(
            title: title,
            position: position,
            image: "https://example.com/\(position).jpg",
            lastUpdate: "2026-10-01T10:00:00.000Z",
            attributionText: nil,
            attributionURL: "https://example.com/autor"
        )
        try await reaction.save(on: app.db)
        return try #require(reaction.id)
    }

    private func addViews(_ destinationScreen: String, count: Int, daysAgo: Double = 0, on app: Application) async throws {
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

    @Test func `Top 3 returns today's most viewed reactions as JSON`() async throws {
        try await withTestApp { app in
            let hmm = try await createReaction("Hmm", position: 4, on: app)
            let rindo = try await createReaction("Rindo", position: 2, on: app)
            let chocado = try await createReaction("Chocado", position: 3, on: app)
            try await createReaction("Bravo", position: 5, on: app)
            try await addViews("didViewReaction(Hmm)", count: 3, on: app)
            try await addViews("didViewReaction(Rindo)", count: 2, on: app)
            try await addViews("didViewReaction(Chocado)", count: 1, on: app)
            // Only today counts, and the tab itself isn't a reaction.
            try await addViews("didViewReaction(Bravo)", count: 9, daysAgo: 2, on: app)
            try await addViews("didViewReactionsTab", count: 9, on: app)

            try await app.testing().test(.GET, "api/v4/top-3-reactions") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.map { $0["id"] as? String } == [hmm.uuidString, rindo.uuidString, chocado.uuidString])
                let json = try #require(list.first)
                #expect(Set(json.keys) == ["id", "title", "position", "image", "lastUpdate", "attributionText", "attributionURL"])
                #expect(json["title"] as? String == "Hmm")
                #expect(json["position"] as? Int == 4)
                #expect(json["image"] as? String == "https://example.com/4.jpg")
                #expect(json["lastUpdate"] as? String == "2026-10-01T10:00:00.000Z")
                #expect(json["attributionText"] is NSNull)
                #expect(json["attributionURL"] as? String == "https://example.com/autor")
            }
        }
    }

    /// Old app versions keep logging views of reactions that were deleted since. Those
    /// used to take a slot as an empty reaction; now the next reaction fills it.
    @Test func `Top 3 skips views of deleted reactions`() async throws {
        try await withTestApp { app in
            let hmm = try await createReaction("Hmm", position: 1, on: app)
            let rindo = try await createReaction("Rindo", position: 2, on: app)
            let chocado = try await createReaction("Chocado", position: 3, on: app)
            try await addViews("didViewReaction(Apagada)", count: 9, on: app)
            try await addViews("didViewReaction(Hmm)", count: 3, on: app)
            try await addViews("didViewReaction(Rindo)", count: 2, on: app)
            try await addViews("didViewReaction(Chocado)", count: 1, on: app)

            try await app.testing().test(.GET, "api/v4/top-3-reactions") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([Reaction].self).map(\.id) == [hmm, rindo, chocado])
            }
        }
    }

    @Test func `Top 3 matches titles with their own parentheses`() async throws {
        try await withTestApp { app in
            let serio = try await createReaction("Hmm (sério)", on: app)
            try await addViews("didViewReaction(Hmm (sério))", count: 2, on: app)

            try await app.testing().test(.GET, "api/v4/top-3-reactions") { res async throws in
                let reactions = try res.content.decode([Reaction].self)
                #expect(reactions.map(\.id) == [serio])
                #expect(reactions.first?.title == "Hmm (sério)")
            }
        }
    }

    @Test func `Top 3 is empty without views today`() async throws {
        try await withTestApp { app in
            try await createReaction("Hmm", on: app)
            try await addViews("didViewReaction(Hmm)", count: 2, daysAgo: 2, on: app)

            try await app.testing().test(.GET, "api/v4/top-3-reactions") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([Reaction].self).count == 0)
            }
        }
    }

    // MARK: - reaction-popularity-stats

    @Test func `Popularity returns the top reaction for today the last week and all time`() async throws {
        try await withTestApp { app in
            let hoje = try await createReaction("Hoje", position: 1, on: app)
            let semana = try await createReaction("Semana", position: 2, on: app)
            let sempre = try await createReaction("Sempre", position: 3, on: app)
            try await addViews("didViewReaction(Hoje)", count: 2, on: app)
            try await addViews("didViewReaction(Semana)", count: 3, daysAgo: 3, on: app)
            try await addViews("didViewReaction(Sempre)", count: 10, daysAgo: 60, on: app)
            try await addViews("didViewReactionsTab", count: 50, on: app)

            try await app.testing().test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
                #expect(res.status == .ok)
                let list = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [[String: Any]])
                #expect(list.map { $0["position"] as? String } == ["1", "2", "3"])
                #expect(list.map { $0["description"] as? String } == ["hoje", "última semana", "todos os tempos"])
                #expect(list.map { ($0["reaction"] as? [String: Any])?["id"] as? String } == [hoje.uuidString, semana.uuidString, sempre.uuidString])
                let first = try #require(list.first)
                #expect(Set(first.keys) == ["position", "reaction", "description"])
                let reaction = try #require(first["reaction"] as? [String: Any])
                #expect(reaction["title"] as? String == "Hoje")
                #expect(reaction["position"] as? Int == 1)
            }
        }
    }

    @Test func `Popularity skips views of deleted reactions`() async throws {
        try await withTestApp { app in
            let semana = try await createReaction("Semana", on: app)
            try await addViews("didViewReaction(Apagada)", count: 9, daysAgo: 3, on: app)
            try await addViews("didViewReaction(Semana)", count: 1, daysAgo: 3, on: app)

            try await app.testing().test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
                let stats = try res.content.decode([TopChartReaction].self)
                #expect(stats.map(\.position) == ["2", "3"])
                #expect(stats.map(\.reaction.id) == [semana, semana])
            }
        }
    }

    /// Each period only appears when it had any views.
    @Test func `Popularity leaves out periods without views`() async throws {
        try await withTestApp { app in
            let sempre = try await createReaction("Sempre", on: app)
            try await addViews("didViewReaction(Sempre)", count: 1, daysAgo: 60, on: app)

            try await app.testing().test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
                let stats = try res.content.decode([TopChartReaction].self)
                #expect(stats.map(\.position) == ["3"])
                #expect(stats.first?.reaction.id == sempre)
            }

            try await UsageMetric.query(on: app.db).delete()
            try await app.testing().test(.GET, "api/v3/reaction-popularity-stats") { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([TopChartReaction].self).count == 0)
            }
        }
    }
}
