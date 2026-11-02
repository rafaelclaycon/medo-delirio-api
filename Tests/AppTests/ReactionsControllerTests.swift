@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct ReactionsControllerTests {

    @discardableResult
    private func createReaction(title: String = "Hmm", position: Int = 1, on app: Application) async throws -> UUID {
        let reaction = Reaction(
            title: title,
            position: position,
            image: "https://example.com/\(title).jpg",
            lastUpdate: "2026-10-01T10:00:00.000Z",
            attributionText: "Foto: Fulano",
            attributionURL: nil
        )
        try await reaction.save(on: app.db)
        return try #require(reaction.id)
    }

    private func addSound(_ soundId: String, to reactionId: String, position: Int = 1, on app: Application) async throws {
        try await ReactionSound(reactionId: reactionId, soundId: soundId, dateAdded: "2026-10-01T10:00:00.000Z", position: position)
            .save(on: app.db)
    }

    private func jsonObject(_ res: TestingHTTPResponse) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(res.body.readableBytesView))
    }

    // MARK: - GET

    @Test func `Get reaction returns the reaction JSON`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(title: "Hmm", position: 3, on: app)

            try await app.testing().test(.GET, "api/v4/reaction/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let json = try #require(try self.jsonObject(res) as? [String: Any])
                #expect(Set(json.keys) == ["id", "title", "position", "image", "lastUpdate", "attributionText", "attributionURL"])
                #expect(json["id"] as? String == id.uuidString)
                #expect(json["title"] as? String == "Hmm")
                #expect(json["position"] as? Int == 3)
                #expect(json["image"] as? String == "https://example.com/Hmm.jpg")
                #expect(json["lastUpdate"] as? String == "2026-10-01T10:00:00.000Z")
                #expect(json["attributionText"] as? String == "Foto: Fulano")
                #expect(json["attributionURL"] is NSNull)
            })
        }
    }

    @Test func `Get reaction is not found for an unknown id`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/reaction/\(UUID().uuidString)", afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Get reaction with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.GET, "api/v4/reaction/not-a-uuid", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test func `All reactions returns every reaction`() async throws {
        try await withTestApp { app in
            let first = try await createReaction(title: "A", position: 1, on: app)
            let second = try await createReaction(title: "B", position: 2, on: app)

            try await app.testing().test(.GET, "api/v4/reactions", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(Set(try res.content.decode([Reaction].self).compactMap(\.id)) == [first, second])
            })
        }
    }

    @Test func `Reaction sounds returns the reaction's sounds as JSON`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            let other = try await createReaction(title: "Outra", on: app)
            try await addSound("SOUND-1", to: id.uuidString, position: 1, on: app)
            try await addSound("SOUND-2", to: id.uuidString, position: 2, on: app)
            try await addSound("SOUND-3", to: other.uuidString, on: app)

            try await app.testing().test(.GET, "api/v4/reaction-sounds/\(id.uuidString)", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let list = try #require(try self.jsonObject(res) as? [[String: Any]])
                #expect(Set(list.compactMap { $0["soundId"] as? String }) == ["SOUND-1", "SOUND-2"])
                let json = try #require(list.first { $0["soundId"] as? String == "SOUND-2" })
                #expect(Set(json.keys) == ["id", "reactionId", "soundId", "dateAdded", "position"])
                #expect(json["reactionId"] as? String == id.uuidString)
                #expect(json["dateAdded"] as? String == "2026-10-01T10:00:00.000Z")
                #expect(json["position"] as? Int == 2)
            })
        }
    }

    /// The reaction id is compared as text, so its case has to match how it was stored.
    @Test func `Reaction sounds match the reaction id exactly`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            try await addSound("SOUND-1", to: id.uuidString, on: app)

            try await app.testing().test(.GET, "api/v4/reaction-sounds/\(id.uuidString.lowercased())", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([ReactionSound].self).count == 0)
            })
        }
    }

    @Test func `Reactions for sound returns the reactions that contain it`() async throws {
        try await withTestApp { app in
            let withSound = try await createReaction(title: "Com", on: app)
            let withSoundLowercased = try await createReaction(title: "Com minúsculas", on: app)
            let withoutSound = try await createReaction(title: "Sem", on: app)
            try await addSound("SOUND-1", to: withSound.uuidString, on: app)
            try await addSound("SOUND-1", to: withSoundLowercased.uuidString.lowercased(), on: app)
            try await addSound("SOUND-2", to: withoutSound.uuidString, on: app)
            // Entries pointing at something that isn't a reaction id are skipped.
            try await addSound("SOUND-1", to: "not-a-uuid", on: app)

            try await app.testing().test(.GET, "api/v4/reactions-for-sound/SOUND-1", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(Set(try res.content.decode([Reaction].self).compactMap(\.id)) == [withSound, withSoundLowercased])
            })
        }
    }

    @Test func `Reactions for a sound in no reaction is empty`() async throws {
        try await withTestApp { app in
            try await createReaction(on: app)

            try await app.testing().test(.GET, "api/v4/reactions-for-sound/SOUND-NOWHERE", afterResponse: { res async throws in
                #expect(res.status == .ok)
                #expect(try res.content.decode([Reaction].self).count == 0)
            })
        }
    }

    // MARK: - PUT

    @Test func `Update reaction replaces every field`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(title: "Antigo", position: 1, on: app)
            let body = #"{"id": "\#(id.uuidString)", "title": "Novo", "position": 7, "image": "https://example.com/novo.jpg", "lastUpdate": "2026-11-01T10:00:00.000Z", "attributionText": null, "attributionURL": "https://example.com/autor"}"#

            try await app.testing().test(.PUT, "api/v4/reaction/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })

            let saved = try await Reaction.find(id, on: app.db)
            #expect(saved?.title == "Novo")
            #expect(saved?.position == 7)
            #expect(saved?.image == "https://example.com/novo.jpg")
            #expect(saved?.lastUpdate == "2026-11-01T10:00:00.000Z")
            #expect(saved?.attributionText == nil)
            #expect(saved?.attributionURL == "https://example.com/autor")
        }
    }

    @Test func `Update reaction is not found for an unknown reaction`() async throws {
        try await withTestApp { app in
            let body = #"{"id": "\#(UUID().uuidString)", "title": "Novo", "position": 7, "image": "", "lastUpdate": ""}"#

            try await app.testing().test(.PUT, "api/v4/reaction/\(TestEnvironment.testPassword)", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .notFound)
            })
        }
    }

    @Test func `Update reaction rejects a wrong password`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(title: "Antigo", on: app)
            let body = #"{"id": "\#(id.uuidString)", "title": "Novo", "position": 7, "image": "", "lastUpdate": ""}"#

            try await app.testing().test(.PUT, "api/v4/reaction/wrong", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: body)
            }, afterResponse: { res async in
                #expect(res.status == .forbidden)
            })
            let saved = try await Reaction.find(id, on: app.db)
            #expect(saved?.title == "Antigo")
        }
    }

    // MARK: - DELETE

    @Test func `Delete all reactions leaves their sounds`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            try await createReaction(title: "Outra", on: app)
            try await addSound("SOUND-1", to: id.uuidString, on: app)

            try await app.testing().test(.DELETE, "api/v4/delete-all-reactions/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
            let reactionCount = try await Reaction.query(on: app.db).count()
            let soundCount = try await ReactionSound.query(on: app.db).count()
            #expect(reactionCount == 0)
            #expect(soundCount == 1)
        }
    }

    @Test func `Delete all reaction sounds leaves the reactions`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            try await addSound("SOUND-1", to: id.uuidString, on: app)
            try await addSound("SOUND-2", to: UUID().uuidString, on: app)

            try await app.testing().test(.DELETE, "api/v4/delete-all-reaction-sounds/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
            let reactionCount = try await Reaction.query(on: app.db).count()
            let soundCount = try await ReactionSound.query(on: app.db).count()
            #expect(reactionCount == 1)
            #expect(soundCount == 0)
        }
    }

    @Test func `Delete reaction sounds only removes that reaction's sounds`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            let other = try await createReaction(title: "Outra", on: app)
            try await addSound("SOUND-1", to: id.uuidString, on: app)
            try await addSound("SOUND-2", to: id.uuidString, on: app)
            try await addSound("SOUND-3", to: other.uuidString, on: app)

            try await app.testing().test(.DELETE, "api/v4/delete-reaction-sounds/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
            let remaining = try await ReactionSound.query(on: app.db).all().map(\.soundId)
            #expect(remaining == ["SOUND-3"])
            let reactionCount = try await Reaction.query(on: app.db).count()
            #expect(reactionCount == 2)
        }
    }

    @Test func `Delete reaction sounds for a reaction without sounds is OK`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v4/delete-reaction-sounds/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    @Test func `Delete reaction removes only the reaction not its sounds`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            let other = try await createReaction(title: "Outra", on: app)
            try await addSound("SOUND-1", to: id.uuidString, on: app)

            try await app.testing().test(.DELETE, "api/v4/delete-reaction/\(id.uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
            let remaining = try await Reaction.query(on: app.db).all().compactMap(\.id)
            #expect(remaining == [other])
            let soundCount = try await ReactionSound.query(on: app.db).count()
            #expect(soundCount == 1)
        }
    }

    /// Deleting by query doesn't check that anything matched.
    @Test func `Delete reaction for an unknown id is still OK`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v4/delete-reaction/\(UUID().uuidString)/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .ok)
            })
        }
    }

    @Test func `Delete reaction with an invalid id is a bad request`() async throws {
        try await withTestApp { app in
            try await app.testing().test(.DELETE, "api/v4/delete-reaction/not-a-uuid/\(TestEnvironment.testPassword)", afterResponse: { res async in
                #expect(res.status == .badRequest)
            })
        }
    }

    @Test func `Every delete rejects a wrong password`() async throws {
        try await withTestApp { app in
            let id = try await createReaction(on: app)
            try await addSound("SOUND-1", to: id.uuidString, on: app)

            for path in [
                "delete-all-reactions/wrong",
                "delete-all-reaction-sounds/wrong",
                "delete-reaction-sounds/\(id.uuidString)/wrong",
                "delete-reaction/\(id.uuidString)/wrong",
            ] {
                try await app.testing().test(.DELETE, "api/v4/\(path)", afterResponse: { res async in
                    #expect(res.status == .forbidden, "\(path)")
                })
            }
            let reactionCount = try await Reaction.query(on: app.db).count()
            let soundCount = try await ReactionSound.query(on: app.db).count()
            #expect(reactionCount == 1)
            #expect(soundCount == 1)
        }
    }
}
