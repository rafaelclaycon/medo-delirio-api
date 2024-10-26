//
//  ReactionContainers.swift
//  medo-delirio-api
//
//  Created by Rafael Claycon Schmitt on 12/12/22.
//

import Vapor

struct ReactionContainer: Content {

    var reaction: Reaction
    var password: String?
}

struct ReactionSoundContainer: Content {

    var sounds: [ReactionSound]
    var password: String?
}
