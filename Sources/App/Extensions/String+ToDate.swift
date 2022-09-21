//
//  File.swift
//  
//
//  Created by Rafael Claycon Schmitt on 18/09/22.
//

import Foundation

extension String {

    var toDate: Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return dateFormatter.date(from: self)!
    }

}
