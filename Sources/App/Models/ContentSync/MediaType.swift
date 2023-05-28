//
//  MediaType.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 03/05/23.
//

import Foundation

enum MediaType: Int, Codable {
    
    case sound, author, song
    
    static func from(string inputString: String) -> MediaType? {
        switch inputString {
        case "sound":
            return .sound
            
        case "author":
            return .author
            
        case "song":
            return .song
            
        default:
            return nil
        }
    }
}
