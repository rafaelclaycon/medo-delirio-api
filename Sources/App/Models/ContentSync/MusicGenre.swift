//
//  MusicGenre.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/08/23.
//

import Fluent
import Vapor

final class MusicGenre: Model, Content {

    static let schema = "MusicGenre"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "symbol")
    var symbol: String

    @Field(key: "name")
    var name: String

    @Field(key: "isHidden")
    var isHidden: Bool

    init() { }
}
