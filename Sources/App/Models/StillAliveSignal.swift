import Fluent
import Vapor

final class StillAliveSignal: Model, Content {

    static let schema = "StillAliveSignal"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "systemName")
    var systemName: String
    
    @Field(key: "systemVersion")
    var systemVersion: String
    
    @Field(key: "currentTimeZone")
    var currentTimeZone: String
    
    @Field(key: "dateTime")
    var dateTime: Date

    init() { }

    init(id: UUID? = nil,
         systemName: String,
         systemVersion: String,
         currentTimeZone: String,
         dateTime: Date) {
        self.id = id
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.currentTimeZone = currentTimeZone
        self.dateTime = dateTime
    }

}
