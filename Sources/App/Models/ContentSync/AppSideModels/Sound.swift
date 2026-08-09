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

struct SoundV2: Hashable, Codable, Identifiable, Content {

    let id: String
    let title: String
    let authorIds: [String]
    let authorName: String?
    let description: String
    let filename: String
    let dateAdded: Date?
    let duration: Double
    let isOffensive: Bool
    let isFromServer: Bool?

    init(
        content: MedoContent,
        authors: [Author]
    ) {
        self.id = content.id?.uuidString ?? ""
        self.title = content.title
        self.authorIds = authors.compactMap { $0.id?.uuidString }
        self.authorName = nil
        self.description = content.description
        self.filename = "\(content.fileId).mp3"
        self.dateAdded = content.creationDate.iso8601withFractionalSeconds
        self.duration = content.duration
        self.isOffensive = content.isOffensive
        self.isFromServer = true
    }
}
