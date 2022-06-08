import Fluent
import Vapor
import SQLiteNIO

func routes(_ app: Application) throws {
    
    // MARK: - API V1
    
    app.get("api", "v1", "status-check") { req in
        return "Conexão com o servidor OK."
        // TODO: Add is-accepting-new-transactions property.
    }

    app.get("api", "v1", "hello", ":name") { req -> String in
        guard let name = req.parameters.get("name") else {
            throw Abort(.internalServerError)
        }
        return "Hello, \(name)!"
    }
    
    app.post("api", "v1", "share-count-stat") { req -> EventLoopFuture<ShareCountStat> in
        let stat = try req.content.decode(ShareCountStat.self)
        return stat.save(on: req.db).map {
            stat
        }
    }
    
    app.post("api", "v1", "client-device-info") { req -> EventLoopFuture<ClientDeviceInfo> in
        let info = try req.content.decode(ClientDeviceInfo.self)
        return info.save(on: req.db).map {
            info
        }
    }
    
    app.get("api", "v1", "all-client-device-info") { req -> EventLoopFuture<[ClientDeviceInfo]> in
        ClientDeviceInfo.query(on: req.db).all()
    }
    
    app.get("api", "v1", "all-sound-share-count-stats") { req -> EventLoopFuture<[ShareCountStat]> in
        ShareCountStat.query(on: req.db).all()
    }
    
    app.get("api", "v1", "sound-share-count-stats") { req -> EventLoopFuture<[ShareCountStat]> in
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select s.contentId, sum(s.shareCount) totalShareCount
                from ShareCountStat s
                where s.contentType = 0
                group by s.contentId
                order by totalShareCount desc
            """
            
            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(ShareCountStat(installId: "", contentId: row.column("contentId")?.string ?? "", contentType: 0, shareCount: row.column("totalShareCount")?.integer ?? 0))
            }
        } else {
            return req.eventLoop.makeSucceededFuture([ShareCountStat]())
        }
    }

    //try app.register(collection: TodoController())
}

struct InfoData: Content {

    let name: String

}
