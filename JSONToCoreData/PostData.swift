//
//  PostData.swift
//  JSONToCoreData
//
//  Created by Jonathan Badger on 10/1/21.
//

import Foundation

struct PostData: Decodable {
    let userId: Int
    let id: Int
    let title: String
    let body: String
}

extension PostData {
    func propertyDictionary() -> [String: Any] {
        //Used to translate JSON decoded struct to NSManagedObject Entity
        let mirror = Mirror(reflecting: self)
        var propertyDict: [String: Any] = [:]
        for child in mirror.children {
            if let propertyName = child.label {
                propertyDict[propertyName] = child.value
            }
        }
        return propertyDict
    }
}
