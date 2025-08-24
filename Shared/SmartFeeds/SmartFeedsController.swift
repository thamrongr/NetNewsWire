//
//  SmartFeedsController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 12/16/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import Account

final class SmartFeedsController: DisplayNameProvider, ContainerIdentifiable {
	
	var containerID: ContainerIdentifier? {
		return ContainerIdentifier.smartFeedController
	}

        public static let shared = SmartFeedsController()
        let nameForDisplay = NSLocalizedString("Smart Feeds", comment: "Smart Feeds group title")

        private var userSearchKeywords = [String]()
        private var userSearchFeeds = [SmartFeed]()

        private(set) var smartFeeds = [Feed]()
        let todayFeed = SmartFeed(delegate: TodayFeedDelegate())
        let unreadFeed = UnreadFeed()
        let starredFeed = SmartFeed(delegate: StarredFeedDelegate())

        private init() {
                userSearchKeywords = AppDefaults.shared.smartFeedKeywords
                userSearchFeeds = userSearchKeywords.map { SmartFeed(delegate: SearchFeedDelegate(searchString: $0)) }
                rebuildSmartFeeds()
        }

        func addSearchFeed(keyword: String) {
                guard !userSearchKeywords.contains(keyword) else { return }
                userSearchKeywords.append(keyword)
                userSearchFeeds.append(SmartFeed(delegate: SearchFeedDelegate(searchString: keyword)))
                saveSearchKeywords()
                rebuildSmartFeeds()
                NotificationCenter.default.post(name: .ChildrenDidChange, object: self)
        }

        private func rebuildSmartFeeds() {
                smartFeeds = [todayFeed, unreadFeed, starredFeed] + userSearchFeeds
        }

        private func saveSearchKeywords() {
                AppDefaults.shared.smartFeedKeywords = userSearchKeywords
        }

        func find(by identifier: FeedIdentifier) -> PseudoFeed? {
                for feed in smartFeeds {
                        if let id = feed.feedID, id == identifier {
                                return feed as? PseudoFeed
                        }
                }
                return nil
        }

}
