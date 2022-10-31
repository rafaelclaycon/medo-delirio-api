//
//  configure.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 01/06/22.
//

import Fluent
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    app.migrations.add(CreateShareCountStat())
    app.migrations.add(CreateClientDeviceInfo())
    app.migrations.add(CreateShareBundleIdLog())
    app.migrations.add(CreatePushDevice())
    app.migrations.add(AddDateFieldToShareCountStat())
    app.migrations.add(CreateUserFolderLog())
    app.migrations.add(CreateUserFolderContentLog())
    app.migrations.add(CreateStillAliveSignal())
    app.migrations.add(CreateContentCollection())
    app.migrations.add(CreateCollectionSound())
    
    app.logger.logLevel = .debug
    
    try app.autoMigrate().wait()
    
    try routes(app)
    
    try app.configurePush()
}
