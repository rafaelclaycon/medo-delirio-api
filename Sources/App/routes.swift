import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "Shantay you stay! medo-delirio-api is up and running."
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
    
    app.get("api", "ShareCountStats") { req -> EventLoopFuture<[ShareCountStat]> in
        ShareCountStat.query(on: req.db).all()
    }

    //try app.register(collection: TodoController())
}

struct InfoData: Content {

    let name: String

}
