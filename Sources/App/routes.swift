import Fluent
import Vapor
import SQLiteNIO

func routes(_ app: Application) throws {
    app.get { req in
        return "Conexão com o servidor OK."
    }

    app.get("hello", ":name") { req -> String in
        guard let name = req.parameters.get("name") else {
            throw Abort(.internalServerError)
        }
        return "Hello, \(name)!"
    }
    
    app.post("api", "ShareCountStat") { req -> EventLoopFuture<ShareCountStat> in
        let stat = try req.content.decode(ShareCountStat.self)
        return stat.save(on: req.db).map {
            stat
        }
    }
    
    app.get("api", "AllSoundShareCountStats") { req -> EventLoopFuture<[ShareCountStat]> in
        ShareCountStat.query(on: req.db).all()
    }
    
    app.get("api", "SoundShareCountStats") { req -> EventLoopFuture<[ShareCountStat]> in
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
