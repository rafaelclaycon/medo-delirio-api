//
//  ClientLoggingController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct ClientLoggingController {
    
    func postClientDeviceInfoHandlerV1(req: Request) async throws -> ClientDeviceInfo {
        let incoming = try req.content.decode(ClientDeviceInfo.self)

        // This endpoint receives two independent one-shot pings per install: the device
        // model name, and the Apple Watch pairing status. They can arrive in any order,
        // and the model ping omits `isWatchPaired`. Upsert by installId so the two pings
        // land on a single row, and never let a missing `isWatchPaired` clear a value
        // that was already reported.
        guard let existing = try await ClientDeviceInfo.query(on: req.db)
            .filter(\ClientDeviceInfo.$installId, .equal, incoming.installId)
            .first()
        else {
            try await incoming.save(on: req.db)
            return incoming
        }

        if !incoming.modelName.isEmpty {
            existing.modelName = incoming.modelName
        }
        if let incomingIsWatchPaired = incoming.isWatchPaired {
            existing.isWatchPaired = incomingIsWatchPaired
        }
        try await existing.save(on: req.db)
        return existing
    }
    
    func postUserFolderLogsHandlerV1(req: Request) async throws -> HTTPStatus {
        let folderLogs = try req.content.decode([UserFolderLog].self)
        
        try await req.db.transaction { transaction in
            for log in folderLogs {
                try await log.save(on: transaction)
            }
        }
        return .ok
    }
    
    func postUserFolderContentLogsHandlerV1(req: Request) async throws -> HTTPStatus {
        let contentLogs = try req.content.decode([UserFolderContentLog].self)
        
        try await req.db.transaction { transaction in
            for log in contentLogs {
                try await log.save(on: transaction)
            }
        }
        return .ok
    }
    
    func postStillAliveSignalHandlerV1(req: Request) async throws -> HTTPStatus {
        let signal = try req.content.decode(StillAliveSignal.self)
        
        try await req.db.transaction { transaction in
            try await signal.save(on: transaction)
        }
        return .ok
    }
    
    func postUsageMetricHandlerV2(req: Request) async throws -> HTTPStatus {
        let metric = try req.content.decode(UsageMetric.self)
        try await req.db.transaction { transaction in
            try await metric.save(on: transaction)
        }
        return .ok
    }
}
