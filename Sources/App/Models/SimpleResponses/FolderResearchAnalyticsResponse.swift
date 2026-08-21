//
//  FolderResearchAnalyticsResponse.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 21/08/26.
//

import Vapor

struct FolderResearchAnalyticsResponse: Content {

    let totalUsers: Int
    let totalFolders: Int
    let totalContentItems: Int
    let topFolderNames: [FolderResearchNameCount]
    let topEmojis: [FolderResearchNameCount]
    let topBackgroundColors: [FolderResearchNameCount]
    let users: [FolderResearchUser]
}

struct FolderResearchNameCount: Content {

    let name: String
    let count: Int
}

struct FolderResearchUser: Content {

    let installId: String
    let folderCount: Int
    let contentCount: Int
    let lastActivity: String
    let devices: [FolderResearchDevice]
    let folders: [FolderResearchFolder]
}

struct FolderResearchDevice: Content {

    let modelName: String
    let firstSeen: String
    let lastSeen: String
}

struct FolderResearchFolder: Content {

    let folderId: String
    let name: String
    let symbol: String
    let backgroundColor: String
    let contentCount: Int
    let createdAt: String
    let lastUpdated: String
    let changeCount: Int
    let history: [String]
    let contents: [FolderResearchContentItem]
}

struct FolderResearchContentItem: Content {

    let contentId: String
    let title: String
    let contentType: String
    let authorName: String?
}
