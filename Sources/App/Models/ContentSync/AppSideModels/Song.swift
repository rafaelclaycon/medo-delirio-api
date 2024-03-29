//
//  Song.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 24/05/23.
//

import Foundation
import Fluent
import Vapor

struct Song: Hashable, Codable, Identifiable, Content {

    let id: String
    let title: String
    let description: String
    let genreId: String
    let duration: Double
    let filename: String
    var dateAdded: Date?
    let isOffensive: Bool
    var isFromServer: Bool?

    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        genreId: String,
        duration: Double = 0,
        filename: String = "",
        dateAdded: Date = Date(),
        isOffensive: Bool = false,
        isFromServer: Bool? = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.genreId = genreId
        self.duration = duration
        self.filename = filename
        self.dateAdded = dateAdded
        self.isOffensive = isOffensive
        self.isFromServer = isFromServer
    }

    init(
        content: MedoContent
    ) {
        self.id = content.id?.uuidString ?? ""
        self.title = content.title
        self.description = content.description
        self.genreId = content.musicGenre ?? "16B61F20-5D24-429F-8751-55F62DBB8DA8" // Gênero indefinido
        self.duration = content.duration
        self.filename = "\(content.fileId).mp3"
        self.dateAdded = content.creationDate.iso8601withFractionalSeconds
        self.isOffensive = content.isOffensive
        self.isFromServer = true
    }
}
