//
//  EventType.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 03/05/23.
//

import Foundation

enum EventType: Int, Codable {
    
    case created, metadataUpdated, fileUpdated, deleted
}
