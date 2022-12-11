//
//  CreateUsageMetric.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 11/12/22.
//

import Fluent

struct CreateUsageMetric: AsyncMigration {

    func prepare(on database: Database) async throws {
        try await database.schema("UsageMetric")
            .id()
            .field("customInstallId", .string, .required)
            .field("originatingScreen", .string, .required)
            .field("destinationScreen", .string, .required)
            .field("systemName", .string, .required)
            .field("isiOSAppOnMac", .bool, .required)
            .field("appVersion", .string, .required)
            .field("dateTime", .string, .required)
            .field("currentTimeZone", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("UsageMetric").delete()
    }

}
