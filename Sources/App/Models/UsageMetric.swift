//
//  UsageMetric.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 11/12/22.
//

import Fluent
import Vapor

final class UsageMetric: Model, Content {

    static let schema = "UsageMetric"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "customInstallId")
    var customInstallId: String
    
    @Field(key: "originatingScreen")
    var originatingScreen: String
    
    @Field(key: "destinationScreen")
    var destinationScreen: String
    
    @Field(key: "systemName")
    var systemName: String
    
    @Field(key: "isiOSAppOnMac")
    var isiOSAppOnMac: Bool
    
    @Field(key: "appVersion")
    var appVersion: String
    
    @Field(key: "dateTime")
    var dateTime: String
    
    @Field(key: "currentTimeZone")
    var currentTimeZone: String
    
    init() { }
    
    init(id: UUID? = nil,
         customInstallId: String,
         originatingScreen: String,
         destinationScreen: String,
         systemName: String,
         isiOSAppOnMac: Bool,
         appVersion: String,
         dateTime: String,
         currentTimeZone: String) {
        self.id = id
        self.customInstallId = customInstallId
        self.originatingScreen = originatingScreen
        self.destinationScreen = destinationScreen
        self.systemName = systemName
        self.isiOSAppOnMac = isiOSAppOnMac
        self.appVersion = appVersion
        self.dateTime = dateTime
        self.currentTimeZone = currentTimeZone
    }

}
