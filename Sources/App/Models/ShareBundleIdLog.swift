import Fluent
import Vapor

final class ShareBundleIdLog: Model, Content, @unchecked Sendable {

    static let schema = "ShareBundleIdLog"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "bundleId")
    var bundleId: String
    
    @Field(key: "count")
    var count: Int

    init() { }

    init(id: UUID? = nil, bundleId: String, count: Int) {
        self.id = id
        self.bundleId = bundleId
        self.count = count
    }

}
