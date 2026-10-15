//
//  Author.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 02/05/23.
//

import Fluent
import Vapor

final class Author: Model, Content, @unchecked Sendable {

    static let schema = "Author"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "photo")
    var photo: String?

    @Field(key: "description")
    var description: String?

    @Field(key: "isHidden")
    var isHidden: Bool?

    @Field(key: "externalLinks")
    var externalLinks: String?

    /// Where the author sits in the app's row of favorite profile photos, from 1. Nil
    /// means not in the row. Curated in MedoHelper, which sends 0 to take an author
    /// out (see `putUpdateAuthorHandlerV3`).
    ///
    /// `@OptionalField`, unlike the fields above: a request without the key (an older
    /// MedoHelper) leaves it unset instead of making it crash the server when read.
    @OptionalField(key: "featuredRank")
    var featuredRank: Int?

    init() { }
}
