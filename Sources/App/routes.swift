import Fluent
import Vapor
import SQLiteNIO

func routes(_ app: Application) throws {
    
    // MARK: - API V1
    
    app.get("api", "v1", "status-check") { req in
        return "Conexão com o servidor OK."
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
    
    app.post("api", "v1", "shared-to-bundle-id") { req -> EventLoopFuture<ShareBundleIdLog> in
        let log = try req.content.decode(ShareBundleIdLog.self)
        return log.save(on: req.db).map {
            log
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
    
    app.get("api", "v1", "install-id-count") { req -> EventLoopFuture<[Int]> in
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select count(c.installId) totalCount
                from ClientDeviceInfo c
                where c.installId not in ("0A4D4541-BC16-4C15-842E-DA6ACF957027","0F1DF136-BECC-4216-ABF5-BC05C91FBB5B","A93E5354-41F9-5170-AFD9-817FAE37D037","F60AF930-0CBA-41FF-A80E-1E6007ED6AE8","F4B0E5C6-32AA-4EA3-BD32-01EE9AD611F4","FC2ADC6B-B70E-4B69-BC69-CCCADB64903F","0A4D4541-BC16-4C15-842E-DA6ACF957027","0F1DF136-BECC-4216-ABF5-BC05C91FBB5B","0F1DF136-BECC-4216-ABF5-BC05C91FBB5B","0A4D4541-BC16-4C15-842E-DA6ACF957027");
            """
            
            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(row.column("totalCount")?.integer ?? 0)
            }
        } else {
            return req.eventLoop.makeSucceededFuture([0])
        }
    }
    
    app.get("api", "v1", "display-ask-for-money-view") { req -> String in
        let userDefaults = UserDefaults.standard
        guard let value = userDefaults.object(forKey: "display-ask-for-money-view") else {
            return "0"
        }
        return String(value as! String)
    }
    
    app.post("api", "v1", "display-ask-for-money-view") { req -> String in
        let newValue = try req.content.decode(String.self)
        let userDefaults = UserDefaults.standard
        if newValue.contains("1") {
            userDefaults.set("1", forKey: "display-ask-for-money-view")
        } else {
            userDefaults.set("0", forKey: "display-ask-for-money-view")
        }
        return "Novo valor setado."
    }
    
    //try app.register(collection: TodoController())
}

struct InfoData: Content {

    let name: String

}
