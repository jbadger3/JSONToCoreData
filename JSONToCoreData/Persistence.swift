//
//  Persistence.swift
//  JSONToCoreData
//
//  Created by Jonathan Badger on 10/1/21.
//

import CoreData

enum PersistanceControllerError: Error {
    case PersistentHistoryChangeError
    case Non200URLStatusCode(statusCode: Int)
    case BatchInsertFailure
}

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    static let preview: PersistenceController = {
        return PersistenceController(inMemory: true)
    }()
    @discardableResult
    static func makePreviews(count: Int) -> [Post] {
        var posts = [Post]()
        let viewContext = PersistenceController.preview.container.viewContext
        for index in 0..<count {
            let post = Post(context: viewContext)
            post.userId = Int64(index)
            post.id = Int64(index)
            post.title = "The \(index) post"
            post.body = "Body of \(index) post"
            posts.append(post)
        }
        return posts
    }
    
    //MARK: Core Data Properties
    lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Posts")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable persistent store remote change notifications
        /// - Tag: persistentStoreRemoteChange
        description.setOption(true as NSNumber,
                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Enable persistent history tracking
        /// - Tag: persistentHistoryTracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        //set a size limit for the journal (wal file) in bytes
        //description.setValue(1048576/2 as NSNumber, forPragmaNamed: "journal_size_limit")

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        // Refresh the UI by consuming store changes via persistent history tracking.
        container.viewContext.automaticallyMergesChangesFromParent = false
        container.viewContext.name = "viewContext"
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        return container
    }()
    
    private var notificationToken: NSObjectProtocol?
    private var lastToken: NSPersistentHistoryToken?
    private var inMemory: Bool
    
    private var urlSession: URLSession
    
    
    init(urlSession: URLSession = URLSession.shared, inMemory: Bool = false) {
        self.urlSession = urlSession
        self.inMemory = inMemory
        notificationToken = NotificationCenter.default.addObserver(forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil) { notification in
            do {
                try self.fetchPersistentHistoryTransactionsAndChanges()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    deinit {
        if let observer = notificationToken {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    //MARK: CoreData
    private func newPrivateContext() -> NSManagedObjectContext {
        // Create a private queue context.
        let taskContext = container.newBackgroundContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        taskContext.undoManager = nil
        return taskContext
    }
    
    private func fetchPersistentHistoryTransactionsAndChanges() throws {
        let taskContext = newPrivateContext()
        taskContext.name = "persistentHistoryContext"
        // Execute the persistent history change since the last transaction.
        let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastToken)
        let historyResult = try taskContext.execute(changeRequest) as? NSPersistentHistoryResult
        if let history = historyResult?.result as? [NSPersistentHistoryTransaction],
           !history.isEmpty {
            self.mergePersistentHistoryChanges(from: history)
            return
        }
        throw PersistanceControllerError.PersistentHistoryChangeError
    }
    
    private func mergePersistentHistoryChanges(from history: [NSPersistentHistoryTransaction]) {
        // Update view context with objectIDs from history change request.
        /// - Tag: mergeChanges
        let viewContext = container.viewContext
        viewContext.perform {
            for transaction in history {
                viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                self.lastToken = transaction.token
            }
        }
    }
    
    func updateDatabase(completion: @escaping (Bool, Error?)->Void) {
        self.downloadPosts { postData, error in
            if let error = error {
                return completion(false, error)
            } else if let postData = postData {
                do {
                    try self.importPosts(from: postData)
                    return completion(true, nil)
                } catch {
                    return completion(false, error)
                }
            }
        }   
    }

    private func downloadPosts(completion: @escaping ([PostData]?, Error?) ->Void) {
        let postsURL = URL(string: "https://jsonplaceholder.typicode.com/posts")!
        let downloadTask = urlSession.dataTask(with: postsURL) { data, response, error in
            if let error = error {
                completion(nil, error)
            }
            if let response = response as? HTTPURLResponse,
               !(200..<300).contains(response.statusCode) {
                return(completion(nil, PersistanceControllerError.Non200URLStatusCode(statusCode: response.statusCode)))
            }
            if let data = data {
                do {
                    let posts = try JSONDecoder().decode([PostData].self, from: data)
                    return(completion(posts, nil))
                } catch {
                    return(completion(nil, error))
                }
            }
        }
        downloadTask.resume()
    }
    
    private func importPosts(from posts:[PostData]) throws {
        let privateContext = newPrivateContext()
        privateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        privateContext.undoManager = nil
        let batchSize = 10
        let numBatches = posts.count/batchSize
        
        for batchNumber in 0..<numBatches {
            let startIndex = batchNumber*batchSize
            let endIndex = batchNumber == (numBatches - 1) ? posts.count - 1 : (startIndex + batchSize)
            let dictionaryObjects = posts[startIndex..<endIndex].map({$0.propertyDictionary()})
            let batchInsertRequest = NSBatchInsertRequest(entityName: "Post", objects: dictionaryObjects)
            let fetchResult = try privateContext.execute(batchInsertRequest)
            if let batchInsertResult = fetchResult as? NSBatchInsertResult,
               let success = batchInsertResult.result as? Bool {
                if !success {
                    throw PersistanceControllerError.BatchInsertFailure
                }
            }
        }
    }
}
