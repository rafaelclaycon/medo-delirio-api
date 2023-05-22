//
//  ClientLoggingController.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 22/05/23.
//

import Vapor

struct ClientLoggingController {
    
    func postClientDeviceInfoHandlerV1(req: Request) throws -> EventLoopFuture<ClientDeviceInfo> {
        let info = try req.content.decode(ClientDeviceInfo.self)
        return info.save(on: req.db).map {
            info
        }
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
