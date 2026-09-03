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

    /// Whether an Apple Watch is paired to this iPhone. Sent once per install by the
    /// client, and only from platforms that support pairing (iPhone). `nil` means
    /// "no information" — an iPad/Mac install, or one that predates this collection.
    /// The device-model ping reuses this same endpoint and omits the field, so it
    /// must never be treated as `false` or used to clear a known value.
    @OptionalField(key: "isWatchPaired")
    var isWatchPaired: Bool?

    init() { }

    init(id: UUID? = nil, installId: String, modelName: String, isWatchPaired: Bool? = nil) {
        self.id = id
        self.installId = installId
        self.modelName = modelName
        self.isWatchPaired = isWatchPaired
    }

}
