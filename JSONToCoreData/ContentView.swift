//
//  ContentView.swift
//  JSONToCoreData
//
//  Created by Jonathan Badger on 10/1/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var persistenceController: PersistenceController

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Post.id, ascending: true)],
        animation: .default)
    private var posts: FetchedResults<Post>

    var body: some View {
        NavigationView {
            List {
                ForEach(posts) { post in
                    NavigationLink(
                        destination: {
                            Text(post.body ?? "")
                        },
                        label: {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(post.title ?? "")
                                        .fontWeight(.bold)
                                }.padding(.bottom, 3)
                                HStack {
                                    Text("id:")
                                        .fontWeight(.semibold)
                                        .font(.caption)
                                    Text(String(post.id))
                                        .font(.caption)
                                    Text("userId:")
                                        .fontWeight(.semibold)
                                        .font(.caption)
                                    Text(String(post.userId))
                                        .font(.caption)
                                }
                            }
                        })
                }
            }
            .toolbar(content: {
                Button(action: {self.updateDatabase()}, label: {Text("Refresh Posts")})
            })
        }
        .onAppear(perform: {self.updateDatabase()})
    }
    func updateDatabase() {
        persistenceController.updateDatabase(completion: { success, error in
            //TODO notify user/handle errors
            if success {
                print("Updated database successfully")
            } else if let error = error {
                print(error.localizedDescription)
            }
        })
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
