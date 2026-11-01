@testable import App
import XCTVapor
import Fluent
import Foundation

final class ReactionsControllerTests: XCTestCase {
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
    private func createReaction(title: String = "Hmm", position: Int = 1) async throws -> UUID {
        let reaction = Reaction(
            title: title,
            position: position,
            image: "https://example.com/\(title).jpg",
            lastUpdate: "2026-10-01T10:00:00.000Z",
            attributionText: "Foto: Fulano",
            attributionURL: nil
        )
        try await reaction.save(on: app.db)
        return try XCTUnwrap(reaction.id)
    }

    private func addSound(_ soundId: String, to reactionId: String, position: Int = 1) async throws {
        try await ReactionSound(reactionId: reactionId, soundId: soundId, dateAdded: "2026-10-01T10:00:00.000Z", position: position)
            .save(on: app.db)
    }

    private func jsonObject(_ res: XCTHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    // MARK: - GET

    func testGetReactionReturnsTheReactionJSON() async throws {
        let id = try await createReaction(title: "Hmm", position: 3)

        try await app.test(.GET, "api/v4/reaction/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let json = try XCTUnwrap(try self.jsonObject(res) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["id", "title", "position", "image", "lastUpdate", "attributionText", "attributionURL"])
            XCTAssertEqual(json["id"] as? String, id.uuidString)
            XCTAssertEqual(json["title"] as? String, "Hmm")
            XCTAssertEqual(json["position"] as? Int, 3)
            XCTAssertEqual(json["image"] as? String, "https://example.com/Hmm.jpg")
            XCTAssertEqual(json["lastUpdate"] as? String, "2026-10-01T10:00:00.000Z")
            XCTAssertEqual(json["attributionText"] as? String, "Foto: Fulano")
            XCTAssertTrue(json["attributionURL"] is NSNull)
        })
    }

    func testGetReactionIsNotFoundForAnUnknownId() async throws {
        try await app.test(.GET, "api/v4/reaction/\(UUID().uuidString)", afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testGetReactionWithAnInvalidIdIsABadRequest() async throws {
        try await app.test(.GET, "api/v4/reaction/not-a-uuid", afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testAllReactionsReturnsEveryReaction() async throws {
        let first = try await createReaction(title: "A", position: 1)
        let second = try await createReaction(title: "B", position: 2)

        try await app.test(.GET, "api/v4/reactions", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(Set(try res.content.decode([Reaction].self).compactMap(\.id)), [first, second])
        })
    }

    func testReactionSoundsReturnsTheReactionsSoundsAsJSON() async throws {
        let id = try await createReaction()
        let other = try await createReaction(title: "Outra")
        try await addSound("SOUND-1", to: id.uuidString, position: 1)
        try await addSound("SOUND-2", to: id.uuidString, position: 2)
        try await addSound("SOUND-3", to: other.uuidString)

        try await app.test(.GET, "api/v4/reaction-sounds/\(id.uuidString)", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            let list = try XCTUnwrap(try self.jsonObject(res) as? [[String: Any]])
            XCTAssertEqual(Set(list.compactMap { $0["soundId"] as? String }), ["SOUND-1", "SOUND-2"])
            let json = try XCTUnwrap(list.first { $0["soundId"] as? String == "SOUND-2" })
            XCTAssertEqual(Set(json.keys), ["id", "reactionId", "soundId", "dateAdded", "position"])
            XCTAssertEqual(json["reactionId"] as? String, id.uuidString)
            XCTAssertEqual(json["dateAdded"] as? String, "2026-10-01T10:00:00.000Z")
            XCTAssertEqual(json["position"] as? Int, 2)
        })
    }

    /// The reaction id is compared as text, so its case has to match how it was stored.
    func testReactionSoundsMatchTheReactionIdExactly() async throws {
        let id = try await createReaction()
        try await addSound("SOUND-1", to: id.uuidString)

        try await app.test(.GET, "api/v4/reaction-sounds/\(id.uuidString.lowercased())", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([ReactionSound].self).count, 0)
        })
    }

    func testReactionsForSoundReturnsTheReactionsThatContainIt() async throws {
        let withSound = try await createReaction(title: "Com")
        let withSoundLowercased = try await createReaction(title: "Com minúsculas")
        let withoutSound = try await createReaction(title: "Sem")
        try await addSound("SOUND-1", to: withSound.uuidString)
        try await addSound("SOUND-1", to: withSoundLowercased.uuidString.lowercased())
        try await addSound("SOUND-2", to: withoutSound.uuidString)
        // Entries pointing at something that isn't a reaction id are skipped.
        try await addSound("SOUND-1", to: "not-a-uuid")

        try await app.test(.GET, "api/v4/reactions-for-sound/SOUND-1", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(Set(try res.content.decode([Reaction].self).compactMap(\.id)), [withSound, withSoundLowercased])
        })
    }

    func testReactionsForASoundInNoReactionIsEmpty() async throws {
        try await createReaction()

        try await app.test(.GET, "api/v4/reactions-for-sound/SOUND-NOWHERE", afterResponse: { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(try res.content.decode([Reaction].self).count, 0)
        })
    }

    // MARK: - PUT

    func testUpdateReactionReplacesEveryField() async throws {
        let id = try await createReaction(title: "Antigo", position: 1)
        let body = #"{"id": "\#(id.uuidString)", "title": "Novo", "position": 7, "image": "https://example.com/novo.jpg", "lastUpdate": "2026-11-01T10:00:00.000Z", "attributionText": null, "attributionURL": "https://example.com/autor"}"#

        try await app.test(.PUT, "api/v4/reaction/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })

        let saved = try await Reaction.find(id, on: app.db)
        XCTAssertEqual(saved?.title, "Novo")
        XCTAssertEqual(saved?.position, 7)
        XCTAssertEqual(saved?.image, "https://example.com/novo.jpg")
        XCTAssertEqual(saved?.lastUpdate, "2026-11-01T10:00:00.000Z")
        XCTAssertNil(saved?.attributionText)
        XCTAssertEqual(saved?.attributionURL, "https://example.com/autor")
    }

    func testUpdateReactionIsNotFoundForAnUnknownReaction() async throws {
        let body = #"{"id": "\#(UUID().uuidString)", "title": "Novo", "position": 7, "image": "", "lastUpdate": ""}"#

        try await app.test(.PUT, "api/v4/reaction/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .notFound)
        })
    }

    func testUpdateReactionRejectsAWrongPassword() async throws {
        let id = try await createReaction(title: "Antigo")
        let body = #"{"id": "\#(id.uuidString)", "title": "Novo", "position": 7, "image": "", "lastUpdate": ""}"#

        try await app.test(.PUT, "api/v4/reaction/wrong", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .forbidden)
        })
        let saved = try await Reaction.find(id, on: app.db)
        XCTAssertEqual(saved?.title, "Antigo")
    }

    // MARK: - DELETE

    func testDeleteAllReactionsLeavesTheirSounds() async throws {
        let id = try await createReaction()
        try await createReaction(title: "Outra")
        try await addSound("SOUND-1", to: id.uuidString)

        try await app.test(.DELETE, "api/v4/delete-all-reactions/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
        let reactionCount = try await Reaction.query(on: app.db).count()
        let soundCount = try await ReactionSound.query(on: app.db).count()
        XCTAssertEqual(reactionCount, 0)
        XCTAssertEqual(soundCount, 1)
    }

    func testDeleteAllReactionSoundsLeavesTheReactions() async throws {
        let id = try await createReaction()
        try await addSound("SOUND-1", to: id.uuidString)
        try await addSound("SOUND-2", to: UUID().uuidString)

        try await app.test(.DELETE, "api/v4/delete-all-reaction-sounds/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
        let reactionCount = try await Reaction.query(on: app.db).count()
        let soundCount = try await ReactionSound.query(on: app.db).count()
        XCTAssertEqual(reactionCount, 1)
        XCTAssertEqual(soundCount, 0)
    }

    func testDeleteReactionSoundsOnlyRemovesThatReactionsSounds() async throws {
        let id = try await createReaction()
        let other = try await createReaction(title: "Outra")
        try await addSound("SOUND-1", to: id.uuidString)
        try await addSound("SOUND-2", to: id.uuidString)
        try await addSound("SOUND-3", to: other.uuidString)

        try await app.test(.DELETE, "api/v4/delete-reaction-sounds/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
        let remaining = try await ReactionSound.query(on: app.db).all().map(\.soundId)
        XCTAssertEqual(remaining, ["SOUND-3"])
        let reactionCount = try await Reaction.query(on: app.db).count()
        XCTAssertEqual(reactionCount, 2)
    }

    func testDeleteReactionSoundsForAReactionWithoutSoundsIsOK() async throws {
        try await app.test(.DELETE, "api/v4/delete-reaction-sounds/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testDeleteReactionRemovesOnlyTheReactionNotItsSounds() async throws {
        let id = try await createReaction()
        let other = try await createReaction(title: "Outra")
        try await addSound("SOUND-1", to: id.uuidString)

        try await app.test(.DELETE, "api/v4/delete-reaction/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
        let remaining = try await Reaction.query(on: app.db).all().compactMap(\.id)
        XCTAssertEqual(remaining, [other])
        let soundCount = try await ReactionSound.query(on: app.db).count()
        XCTAssertEqual(soundCount, 1)
    }

    /// Deleting by query doesn't check that anything matched.
    func testDeleteReactionForAnUnknownIdIsStillOK() async throws {
        try await app.test(.DELETE, "api/v4/delete-reaction/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
        })
    }

    func testDeleteReactionWithAnInvalidIdIsABadRequest() async throws {
        try await app.test(.DELETE, "api/v4/delete-reaction/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
            XCTAssertEqual(res.status, .badRequest)
        })
    }

    func testEveryDeleteRejectsAWrongPassword() async throws {
        let id = try await createReaction()
        try await addSound("SOUND-1", to: id.uuidString)

        for path in [
            "delete-all-reactions/wrong",
            "delete-all-reaction-sounds/wrong",
            "delete-reaction-sounds/\(id.uuidString)/wrong",
            "delete-reaction/\(id.uuidString)/wrong",
        ] {
            try await app.test(.DELETE, "api/v4/\(path)", afterResponse: { res async in
                XCTAssertEqual(res.status, .forbidden, path)
            })
        }
        let reactionCount = try await Reaction.query(on: app.db).count()
        let soundCount = try await ReactionSound.query(on: app.db).count()
        XCTAssertEqual(reactionCount, 1)
        XCTAssertEqual(soundCount, 1)
    }
}
