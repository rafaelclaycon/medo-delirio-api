//
//  EventIdWrapper.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 03/09/23.
//

import Foundation

actor EventIdWrapper {
    var updateEventId: String = ""

    func setUpdateEventId(_ id: String) {
        self.updateEventId = id
    }
}
