//
//  USTC+QCKDDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/24.
//

import SwiftUI
import SwiftyJSON

final class USTCQCKDDelegate: FileADD & LastUpdateADD {
    static var shared = USTCQCKDDelegate()

    // MARK: - Protocol requirements

    typealias D = UstcQCKDModel
    @Published var status: AsyncViewStatus = .inProgress
    var data: UstcQCKDModel = .init() {
        willSet {
            DispatchQueue.main.async {
                withAnimation {
                    self.objectWillChange.send()
                }
            }
        }
    }

    var cache: UstcQCKDModel {
        get {
            data
        }
        set {
            print("cache set")
            data = newValue
        }
    }

    var placeHolderData: UstcQCKDModel = .init()
    var timeInterval: Double?
    var timeCacheName: String = "UstcQCKDClientLastUpdated"
    var cacheName: String = "UstcQCKDClientCache"
    var lastUpdate: Date?

    var ustcQCKDClient = UstcQCKDClient.shared

    func parseCache() async throws -> UstcQCKDModel {
        data
    }

    func refreshCache() async throws {
        async let availableEvents = ustcQCKDClient.fetchAvailableEvents()
        async let doneEvents = ustcQCKDClient.fetchDoneEvents()
        async let myEvents = ustcQCKDClient.fetchMyEvents()

        data = .init(availableEvents: try await availableEvents,
                     doneEvents: try await doneEvents,
                     myEvents: try await myEvents)

        // MARK: This isn't the final optimization though.

        try await afterRefreshCache()
    }

    var nextPageNo = [1, 1, 1]

    func fetchMorePage(for type: String) async throws {
        foregroundUpdateStatus(with: .cached)
        var newValue = data
        do {
            switch type {
            case "Available":
                nextPageNo[0] += 1
                newValue.availableEvents += try await ustcQCKDClient.fetchAvailableEvents(pageNo: nextPageNo[0])
            case "Done":
                nextPageNo[1] += 1
                newValue.doneEvents += try await ustcQCKDClient.fetchDoneEvents(pageNo: nextPageNo[1])
            case "My":
                nextPageNo[2] += 1
                newValue.myEvents += try await ustcQCKDClient.fetchMyEvents(pageNo: nextPageNo[2])
            default:
                return
            }
        } catch {
            foregroundUpdateStatus(with: .failure(error.localizedDescription))
            return
        }
        foregroundUpdateData(with: newValue)
        foregroundUpdateStatus(with: .success)
        try await afterRefreshCache()
    }

    init() {
        afterInit()
    }
}
