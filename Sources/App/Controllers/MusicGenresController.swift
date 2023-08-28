//
//  MusicGenresController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 26/08/23.
//

import Vapor
import Fluent

struct MusicGenresController {

    func postImportMusicGenresHandlerV3(req: Request) async throws -> HTTPStatus {
        let genres = try req.content.decode([MusicGenre].self)
        for i in genres.indices {
            genres[i].isHidden = false
        }
        try await req.db.transaction { transaction in
            try await genres.create(on: transaction)
        }
        return .ok
    }

    func getAllMusicGenresHandlerV3(req: Request) throws -> EventLoopFuture<[MusicGenre]> {
        MusicGenre.query(on: req.db)
            .filter(\.$isHidden == false)
            .all()
    }
}
