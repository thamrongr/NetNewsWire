//
//  CombinedArticleExtractionProgress.swift
//  NetNewsWire
//
//  Created by Codex on 2023-11-23.
//

import Foundation
import RSWeb

extension Notification.Name {
    public static let combinedArticleExtractionProgressDidChange = Notification.Name("combinedArticleExtractionProgressDidChange")
}

/// Combine article extraction progress from multiple accounts for display purposes.
public final class CombinedArticleExtractionProgress {

    public private(set) var numberOfTasks = 0
    public private(set) var numberRemaining = 0
    public private(set) var numberCompleted = 0

    public var isComplete: Bool {
        return numberRemaining < 1
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .DownloadProgressDidChange, object: nil)
    }

    @objc func progressDidChange(_ notification: Notification) {
        var updatedNumberOfTasks = 0
        var updatedNumberRemaining = 0
        var updatedNumberCompleted = 0
        var didMakeChange = false

        let progresses = AccountManager.shared.activeAccounts.map { $0.articleExtractionProgress }
        for progress in progresses {
            updatedNumberOfTasks += progress.numberOfTasks
            updatedNumberRemaining += progress.numberRemaining
            updatedNumberCompleted += progress.numberCompleted
        }

        if updatedNumberOfTasks != numberOfTasks {
            numberOfTasks = updatedNumberOfTasks
            didMakeChange = true
        }

        updatedNumberRemaining = min(updatedNumberRemaining, numberOfTasks)
        if updatedNumberRemaining != numberRemaining {
            numberRemaining = updatedNumberRemaining
            didMakeChange = true
        }

        updatedNumberCompleted = min(updatedNumberCompleted, numberOfTasks)
        if updatedNumberCompleted != numberCompleted {
            numberCompleted = updatedNumberCompleted
            didMakeChange = true
        }

        if didMakeChange {
            NotificationCenter.default.post(name: .combinedArticleExtractionProgressDidChange, object: self)
        }
    }
}

