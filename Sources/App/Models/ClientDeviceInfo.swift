import Fluent
import Vapor

final class ClientDeviceInfo: Model, Content {

    static let schema = "ClientDeviceInfo"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "installId")
    var installId: String
    
    @Field(key: "modelName")
    var modelName: String

    init() { }

    init(id: UUID? = nil, installId: String, modelName: String) {
        self.id = id
        self.installId = installId
        self.modelName = modelName
    }

}
