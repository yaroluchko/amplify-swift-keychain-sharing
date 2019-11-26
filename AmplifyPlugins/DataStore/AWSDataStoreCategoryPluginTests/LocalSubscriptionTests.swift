//
// Copyright 2018-2019 Amazon.com,
// Inc. or its affiliates. All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import XCTest
import SQLite

import Combine
@testable import Amplify
@testable import AmplifyTestCommon
@testable import AWSDataStoreCategoryPlugin

/// Tests behavior of local DataStore subscriptions (as opposed to cloud subscription behaviors)
class LocalSubscriptionTests: XCTestCase {

    override func setUp() {
        super.setUp()

        Amplify.reset()
        Amplify.Logging.logLevel = .verbose

        ModelRegistry.register(modelType: Post.self)
        ModelRegistry.register(modelType: Comment.self)

        let storageAdapter: SQLiteStorageEngineAdapter
        let storageEngine: StorageEngine
        do {
            let connection = try Connection(.inMemory)
            storageAdapter = SQLiteStorageEngineAdapter(connection: connection)
            storageEngine = StorageEngine(adapter: storageAdapter, syncEngineFactory: nil)
        } catch {
            XCTFail(String(describing: error))
            return
        }

        let dataStorePublisher = DataStorePublisher()
        let dataStorePlugin = AWSDataStoreCategoryPlugin(storageEngine: storageEngine,
                                                         dataStorePublisher: dataStorePublisher)

        let dataStoreConfig = DataStoreCategoryConfiguration(plugins: [
            "awsDataStoreCategoryPlugin": true
        ])
        let amplifyConfig = AmplifyConfiguration(dataStore: dataStoreConfig)
        do {
            try Amplify.add(plugin: dataStorePlugin)
            try Amplify.configure(amplifyConfig)
        } catch {
            XCTFail(String(describing: error))
            return
        }
    }

    /// - Given: A configured Amplify system on iOS 13 or higher
    /// - When:
    ///    - I get a publisher observing a model
    /// - Then:
    ///    - I receive notifications for updates to that model
    func testPublisher() {
        let receivedMutationEvent = expectation(description: "Received mutation event")

        let subscription = Amplify.DataStore.publisher(for: Post.self).sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    break
                }
        }, receiveValue: { _ in
            receivedMutationEvent.fulfill()
        })

        let model = Post(id: UUID().uuidString,
                         title: "Test Post",
                         content: "Test Post Content",
                         createdAt: Date(),
                         updatedAt: nil,
                         rating: nil,
                         draft: false,
                         comments: [])

        Amplify.DataStore.save(model) { _ in }
        wait(for: [receivedMutationEvent], timeout: 1.0)
        subscription.cancel()
    }

    /// - Given: A configured DataStore
    /// - When:
    ///    - I subscribe to model events
    /// - Then:
    ///    - I am notified of `create` mutations
    func testCreate() {
        let receivedMutationEvent = expectation(description: "Received mutation event")

        let subscription = Amplify.DataStore.publisher(for: Post.self).sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    break
                }
        }, receiveValue: { mutationEvent in
            if mutationEvent.mutationType == MutationEvent.MutationType.create.rawValue {
                receivedMutationEvent.fulfill()
            }
        })

        let model = Post(id: UUID().uuidString,
                         title: "Test Post",
                         content: "Test Post Content",
                         createdAt: Date(),
                         updatedAt: nil,
                         rating: nil,
                         draft: false,
                         comments: [])

        Amplify.DataStore.save(model) { _ in }
        wait(for: [receivedMutationEvent], timeout: 1.0)

        subscription.cancel()
    }

    /// - Given: A configured DataStore
    /// - When:
    ///    - I subscribe to model events
    /// - Then:
    ///    - I am notified of `update` mutations
    func testUpdate() {
        let originalContent = "Content as of \(Date())"
        let model = Post(id: UUID().uuidString,
                         title: "Test Post",
                         content: originalContent,
                         createdAt: Date(),
                         updatedAt: nil,
                         rating: nil,
                         draft: false,
                         comments: [])

        let saveCompleted = expectation(description: "Save complete")
        Amplify.DataStore.save(model) { _ in
            saveCompleted.fulfill()
        }

        wait(for: [saveCompleted], timeout: 5.0)

        let newContent = "Updated content as of \(Date())"
        let newModel = Post(id: model.id,
                            title: model.title,
                            content: newContent,
                            createdAt: model.createdAt,
                            updatedAt: Date(),
                            rating: model.rating,
                            draft: model.draft)

        let receivedMutationEvent = expectation(description: "Received mutation event")

        let subscription = Amplify.DataStore.publisher(for: Post.self).sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    break
                }
        }, receiveValue: { mutationEvent in
            if mutationEvent.mutationType == MutationEvent.MutationType.update.rawValue {
                receivedMutationEvent.fulfill()
            }
        })

        Amplify.DataStore.save(newModel) { _ in }

        wait(for: [receivedMutationEvent], timeout: 1.0)

        subscription.cancel()
    }

    /// - Given: A configured DataStore
    /// - When:
    ///    - I subscribe to model events
    /// - Then:
    ///    - I am notified of `delete` mutations
    func testDelete() {
        let receivedMutationEvent = expectation(description: "Received mutation event")

        let subscription = Amplify.DataStore.publisher(for: Post.self).sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .finished:
                    break
                }
        }, receiveValue: { mutationEvent in
            if mutationEvent.mutationType == MutationEvent.MutationType.delete.rawValue {
                receivedMutationEvent.fulfill()
            }
        })

        let model = Post(title: "Test Post",
                         content: "Test Post Content")

        Amplify.DataStore.save(model) { _ in }
        Amplify.DataStore.delete(model) { _ in }
        wait(for: [receivedMutationEvent], timeout: 1.0)

        subscription.cancel()
    }

}
