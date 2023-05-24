//
//  MusicGenre.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 24/05/23.
//

import Foundation

enum MusicGenre: String, CaseIterable, Identifiable, Codable {

    case all, arrocha, electronic, funk, undefined, house, jingle, marchinha, metal, mpb, pagode, pisero, pop, rock, samba, sertanejo, tecno, variousGenres
    
    var id: String { String(self.rawValue) }
}
