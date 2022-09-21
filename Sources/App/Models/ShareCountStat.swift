import Fluent
import Vapor

final class ShareCountStat: Model, Content {

    static let schema = "ShareCountStat"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "installId")
    var installId: String
    
    @Field(key: "contentId")
    var contentId: String
    
    @Field(key: "contentType")
    var contentType: Int
    
    @Field(key: "shareCount")
    var shareCount: Int
    
    @Field(key: "date")
    var date: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         installId: String,
         contentId: String,
         contentType: Int,
         shareCount: Int,
         date: Date) {
        self.id = id
        self.installId = installId
        self.contentId = contentId
        self.contentType = contentType
        self.shareCount = shareCount
        self.date = date
    }

}
