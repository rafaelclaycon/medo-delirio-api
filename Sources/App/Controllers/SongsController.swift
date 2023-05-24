//
//  SongsController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 24/05/23.
//

import Vapor
import Fluent

struct SongsController {
    
    func postImportSongsHandlerV3(req: Request) async throws -> HTTPStatus {
        let songs = try req.content.decode([Song].self)
        try await req.db.transaction { transaction in
            for song in songs {
                let medoContent = MedoContent(song: song)
                try await medoContent.create(on: transaction)
            }
        }
        return .ok
    }
    
    func getAllSongsHandlerV3(req: Request) throws -> EventLoopFuture<[Song]> {
        let query = MedoContent.query(on: req.db)
            .filter(\.$contentType == .song)
            .filter(\.$isHidden == false)
        
        return query.all().flatMapThrowing { medoContentList in
            medoContentList.map { content in
                return Song(content: content)
            }
        }
    }
}
