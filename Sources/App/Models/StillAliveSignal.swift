import Fluent
import Vapor

final class StillAliveSignal: Model, Content {

    static let schema = "StillAliveSignal"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "installId")
    var installId: String
    
    @Field(key: "modelName")
    var modelName: String
    
    @Field(key: "systemName")
    var systemName: String
    
    @Field(key: "systemVersion")
    var systemVersion: String
    
    @Field(key: "isiOSAppOnMac")
    var isiOSAppOnMac: Bool
    
    @Field(key: "appVersion")
    var appVersion: String
    
    @Field(key: "currentTimeZone")
    var currentTimeZone: String
    
    @Field(key: "dateTime")
    var dateTime: String
    
    init() { }
    
    init(id: UUID? = nil,
         installId: String,
         modelName: String,
         systemName: String,
         systemVersion: String,
         isiOSAppOnMac: Bool,
         appVersion: String,
         currentTimeZone: String,
         dateTime: String) {
        self.id = id
        self.installId = installId
        self.modelName = modelName
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.isiOSAppOnMac = isiOSAppOnMac
        self.appVersion = appVersion
        self.currentTimeZone = currentTimeZone
        self.dateTime = dateTime
    }

}
