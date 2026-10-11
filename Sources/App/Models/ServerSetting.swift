import Fluent
import Vapor

final class ServerSetting: Model, Content, @unchecked Sendable {

    static let schema = "ServerSetting"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "key")
    var key: String

    @Field(key: "value")
    var value: String

    init() { }

    init(id: UUID? = nil, key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}
