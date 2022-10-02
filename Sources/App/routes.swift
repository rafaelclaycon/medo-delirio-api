import Fluent
import Vapor
import SQLiteNIO
import APNS

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
                where c.installId not in ("0A4D4541-BC16-4C15-842E-DA6ACF957027","0F1DF136-BECC-4216-ABF5-BC05C91FBB5B","A93E5354-41F9-5170-AFD9-817FAE37D037","F60AF930-0CBA-41FF-A80E-1E6007ED6AE8","F4B0E5C6-32AA-4EA3-BD32-01EE9AD611F4","FC2ADC6B-B70E-4B69-BC69-CCCADB64903F","F32538E4-6422-4D6F-9490-0984C17B7D80","285EAE4D-FBDE-482B-B8F2-705A68A67FDC","C78A6C1E-4EE0-521F-9C9E-F9AD9CA6C51D","04BCE1A6-5885-47D7-AD61-A14D6D6B61B7","C0821365-0003-4986-91EE-F9F79CDF4E7A","7CC49574-5275-4490-864B-65551784131F","DFD4128B-65C3-4251-9948-DC85D6E83FBE","E8120B41-E486-4170-95E0-5F13737A85AB");
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
    
    app.get("api", "v1", "display-lula-won-on-lock-screen-widgets") { req -> String in
        let userDefaults = UserDefaults.standard
        guard let value = userDefaults.object(forKey: "display-lula-won-on-lock-screen-widgets") else {
            return "0"
        }
        return String(value as! String)
    }
    
    app.post("api", "v1", "display-lula-won-on-lock-screen-widgets") { req -> String in
        let newValue = try req.content.decode(String.self)
        let userDefaults = UserDefaults.standard
        if newValue.contains("1") {
            userDefaults.set("1", forKey: "display-lula-won-on-lock-screen-widgets")
        } else {
            userDefaults.set("0", forKey: "display-lula-won-on-lock-screen-widgets")
        }
        return "Novo valor setado."
    }
    
    app.get("api", "v1", "any-iphone-14-in-user-stats") { req -> EventLoopFuture<[Int]> in
        if let sqlite = req.db as? SQLiteDatabase {
            let query = """
                select count(c.installId) totalCount
                from ClientDeviceInfo c
                where c.modelName like '%14%'
                group by c.modelName;
            """
            
            return sqlite.query(query).flatMapEach(on: req.eventLoop) { row in
                req.eventLoop.makeSucceededFuture(row.column("totalCount")?.integer ?? 0)
            }
        } else {
            return req.eventLoop.makeSucceededFuture([0])
        }
    }
    
    app.post("api", "v1", "push-device") { req -> EventLoopFuture<PushDevice> in
        let device = try req.content.decode(PushDevice.self)
        return device.save(on: req.db).map {
            device
        }
    }
    
    app.post("api", "v1", "send-push-notification") { req -> HTTPStatus in
        let notif = try req.content.decode(PushNotification.self)
        
        guard let password = notif.password, password == "algal-peroxide-toddy-answer" else {
            return HTTPStatus.unauthorized
        }
        
        PushDevice.query(on: req.db).all().flatMapEach(on: req.eventLoop) { device in
            let payload = APNSwiftPayload(alert: .init(title: notif.title, body: notif.description), sound: .normal("default"))
            return req.apns.send(payload, to: device.pushToken).map { HTTPStatus.ok }
        }
        return HTTPStatus.ok
    }
    
    //try app.register(collection: TodoController())

}

struct InfoData: Content {

    let name: String

}
