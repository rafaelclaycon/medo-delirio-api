@testable import App
import Testing
import VaporTesting
import Fluent
import Foundation

struct SharePostTests {

    /// A fresh app with this suite's fixtures already in place.
    private func withSeededApp(_ test: (Application) async throws -> Void) async throws {
        try await withTestApp { app in
            for (id, type) in [(sound, ContentType.sound), (song, .song)] {
                let content = MedoContent()
                content.id = id
                content.title = "Test"
                content.authorId = ""
                content.description = ""
                content.fileId = ""
                content.creationDate = "2025-01-01T00:00:00.000Z"
                content.duration = 2
                content.isOffensive = false
                content.musicGenre = nil
                content.contentType = type
                content.isHidden = false
                try await content.create(on: app.db)
            }
            try await test(app)
        }
    }

    private let sound = UUID()
    private let song = UUID()

    private func postStat(contentId: String, contentType: Int, extra: String = #", "dateTime": "2026-11-01T10:00:00.000Z""#, on app: Application) async throws -> TestingHTTPResponse {
        let body = #"{"installId": "INSTALL-1", "contentId": "\#(contentId)", "contentType": \#(contentType), "shareCount": 1\#(extra)}"#
        var response: TestingHTTPResponse!
        try await app.testing().test(.POST, "api/v1/share-count-stat", beforeRequest: { req async throws in
            req.headers.contentType = .json
            req.body = ByteBuffer(string: body)
        }, afterResponse: { res async in
            response = res
        })
        return response
    }

    // MARK: - share-count-stat

    @Test func `Posting a share saves it and returns it`() async throws {
        try await withSeededApp { app in
            let res = try await postStat(contentId: sound.uuidString, contentType: 0, on: app)

            #expect(res.status == .ok)
            let json = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
            #expect(Set(json.keys) == ["id", "installId", "contentId", "contentType", "shareCount", "dateTime"])
            #expect(UUID(uuidString: json["id"] as? String ?? "") != nil)
            #expect(json["installId"] as? String == "INSTALL-1")
            #expect(json["contentId"] as? String == sound.uuidString)
            #expect(json["contentType"] as? Int == 0)
            #expect(json["shareCount"] as? Int == 1)
            #expect(json["dateTime"] as? String == "2026-11-01T10:00:00.000Z")

            let saved = try await ShareCountStat.query(on: app.db).all()
            #expect(saved.count == 1)
            #expect(saved.first?.id?.uuidString == json["id"] as? String)
            #expect(saved.first?.dateTime == "2026-11-01T10:00:00.000Z")
        }
    }

    /// The type the app reports only says whether it was a video share; the stored type
    /// follows what the content actually is.
    @Test func `The stored content type follows the content`() async throws {
        try await withSeededApp { app in
            let cases: [(content: UUID, reported: Int, stored: Int)] = [
                (sound, 0, 0), (sound, 1, 0), (sound, 2, 2), (sound, 3, 2),
                (song, 0, 1), (song, 1, 1), (song, 2, 3), (song, 3, 3),
            ]
            for (content, reported, stored) in cases {
                let res = try await postStat(contentId: content.uuidString, contentType: reported, on: app)
                #expect(res.status == .ok)
                #expect(try res.content.decode(ShareCountStat.self).contentType == stored, "\(content == sound ? "sound" : "song") reported as \(reported)")
            }
            let savedTypes = try await ShareCountStat.query(on: app.db).all().map(\.contentType)
            #expect(savedTypes.sorted() == cases.map(\.stored).sorted())
        }
    }

    @Test func `An unknown content type is a bad request`() async throws {
        try await withSeededApp { app in
            let res = try await postStat(contentId: sound.uuidString, contentType: 4, on: app)
            #expect(res.status == .badRequest)
            let count = try await ShareCountStat.query(on: app.db).count()
            #expect(count == 0)
        }
    }

    @Test func `An invalid content id is a bad request`() async throws {
        try await withSeededApp { app in
            let res = try await postStat(contentId: "not-a-uuid", contentType: 0, on: app)
            #expect(res.status == .badRequest)
        }
    }

    @Test func `An unknown content is not found`() async throws {
        try await withSeededApp { app in
            let res = try await postStat(contentId: UUID().uuidString, contentType: 0, on: app)
            #expect(res.status == .notFound)
            let count = try await ShareCountStat.query(on: app.db).count()
            #expect(count == 0)
        }
    }

    /// A lowercase id still finds the content, but the stat keeps the id as sent.
    @Test func `The content id is stored as sent`() async throws {
        try await withSeededApp { app in
            let res = try await postStat(contentId: sound.uuidString.lowercased(), contentType: 0, on: app)
            #expect(res.status == .ok)
            let saved = try await ShareCountStat.query(on: app.db).first()
            #expect(saved?.contentId == sound.uuidString.lowercased())
        }
    }

    @Test func `A share without a date is saved without one`() async throws {
        try await withSeededApp { app in
            let res = try await postStat(contentId: sound.uuidString, contentType: 0, extra: "", on: app)
            #expect(res.status == .ok)
            let saved = try await ShareCountStat.query(on: app.db).first()
            #expect(saved != nil)
            #expect(saved?.dateTime == nil)
        }
    }

    // MARK: - shared-to-bundle-id

    @Test func `Posting a bundle id log saves it and returns it`() async throws {
        try await withSeededApp { app in
            try await app.testing().test(.POST, "api/v1/shared-to-bundle-id", beforeRequest: { req async throws in
                req.headers.contentType = .json
                req.body = ByteBuffer(string: #"{"bundleId": "net.whatsapp.WhatsApp.ShareExtension", "count": 3}"#)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)
                let json = try #require(JSONSerialization.jsonObject(with: Data(res.body.readableBytesView)) as? [String: Any])
                #expect(Set(json.keys) == ["id", "bundleId", "count"])
                #expect(UUID(uuidString: json["id"] as? String ?? "") != nil)
                #expect(json["bundleId"] as? String == "net.whatsapp.WhatsApp.ShareExtension")
                #expect(json["count"] as? Int == 3)
            })

            let saved = try await ShareBundleIdLog.query(on: app.db).all()
            #expect(saved.map(\.bundleId) == ["net.whatsapp.WhatsApp.ShareExtension"])
            #expect(saved.map(\.count) == [3])
        }
    }
}
