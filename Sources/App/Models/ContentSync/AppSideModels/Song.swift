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
    let genre: MusicGenre
    let duration: Double
    let filename: String
    var dateAdded: Date?
    let isOffensive: Bool
    let isNew: Bool?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        genre: MusicGenre = .undefined,
        duration: Double = 0,
        filename: String = "",
        dateAdded: Date = Date(),
        isOffensive: Bool = false,
        isNew: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.genre = genre
        self.duration = duration
        self.filename = filename
        self.dateAdded = dateAdded
        self.isOffensive = isOffensive
        self.isNew = isNew
    }
    
    init(
        content: MedoContent
    ) {
        self.id = content.id?.uuidString ?? ""
        self.title = content.title
        self.description = content.description
        self.genre = MusicGenre(rawValue: content.musicGenre ?? "undefined") ?? .undefined
        self.duration = content.duration
        self.filename = "\(content.fileId).mp3"
        self.dateAdded = content.creationDate.iso8601withFractionalSeconds
        self.isOffensive = content.isOffensive
        self.isNew = false
    }
}
