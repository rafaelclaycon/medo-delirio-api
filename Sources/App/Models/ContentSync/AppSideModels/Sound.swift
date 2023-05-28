//
//  Sound.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 04/05/23.
//

import Foundation
import Fluent
import Vapor

struct Sound: Hashable, Codable, Identifiable, Content {
    
    let id: String
    let title: String
    let authorId: String
    let authorName: String?
    let description: String
    let filename: String
    let dateAdded: Date?
    let duration: Double
    let isOffensive: Bool
    let isFromServer: Bool?
    
    init(
        id: String,
        title: String,
        authorId: String,
        authorName: String?,
        description: String,
        filename: String,
        dateAdded: Date?,
        duration: Double,
        isOffensive: Bool,
        isFromServer: Bool?
    ) {
        self.id = id
        self.title = title
        self.authorId = authorId
        self.authorName = authorName
        self.description = description
        self.filename = filename
        self.dateAdded = dateAdded
        self.duration = duration
        self.isOffensive = isOffensive
        self.isFromServer = isFromServer
    }
    
    init(
        content: MedoContent
    ) {
        self.id = content.id?.uuidString ?? ""
        self.title = content.title
        self.authorId = content.authorId
        self.authorName = nil
        self.description = content.description
        self.filename = "\(content.fileId).mp3"
        self.dateAdded = content.creationDate.iso8601withFractionalSeconds
        self.duration = content.duration
        self.isOffensive = content.isOffensive
        self.isFromServer = true
    }
}
