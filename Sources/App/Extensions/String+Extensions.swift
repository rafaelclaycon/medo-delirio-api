//
//  String+Extensions.swift
//  medo-delirio-api
//
//  Created by Rafael Schmitt on 19/05/23.
//

import Foundation

extension String {
    
    func isUTCDateString() -> Bool {
        let pattern = #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#
        if let _ = self.range(of: pattern, options: .regularExpression) {
            return true
        } else {
            return false
        }
    }
}
