//
//  JSONToCoreDataApp.swift
//  JSONToCoreData
//
//  Created by Jonathan Badger on 10/1/21.
//

import SwiftUI

@main
struct JSONToCoreDataApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
