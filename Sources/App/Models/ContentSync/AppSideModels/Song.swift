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
    let genre: String
    let duration: Double
    let filename: String
    var dateAdded: Date?
    let isOffensive: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        genre: String,
        duration: Double = 0,
        filename: String = "",
        dateAdded: Date = Date(),
        isOffensive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.genre = genre
        self.duration = duration
        self.filename = filename
        self.dateAdded = dateAdded
        self.isOffensive = isOffensive
    }
    
    init(
        content: MedoContent
    ) {
        self.id = content.id?.uuidString ?? ""
        self.title = content.title
        self.description = content.description
        self.genre = content.musicGenre ?? "undefined"
        self.duration = content.duration
        self.filename = "\(content.fileId).mp3"
        self.dateAdded = content.creationDate.iso8601withFractionalSeconds
        self.isOffensive = content.isOffensive
    }
}
