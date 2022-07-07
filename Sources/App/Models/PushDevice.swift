import Fluent
import Vapor

final class PushDevice: Model, Content {

    static let schema = "PushDevice"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "installId")
    var installId: String
    
    @Field(key: "pushToken")
    var pushToken: String
    
    init() { }
    
    init(id: UUID? = nil, installId: String, pushToken: String) {
        self.id = id
        self.installId = installId
        self.pushToken = pushToken
    }

}
