//
//  SidebarStatusBarView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/17/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import Articles
import RSWeb
import Account

final class SidebarStatusBarView: NSView {

	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var progressLabel: NSTextField!
	@IBOutlet var bottomConstraint: NSLayoutConstraint!
	@IBOutlet var heightConstraint: NSLayoutConstraint!

	private var isAnimatingProgress = false

	override var isFlipped: Bool {
		return true
	}

	override func awakeFromNib() {

		progressIndicator.isHidden = true
		progressLabel.isHidden = true

		let progressLabelFontSize = progressLabel.font?.pointSize ?? 13.0
		progressLabel.font = NSFont.monospacedDigitSystemFont(ofSize: progressLabelFontSize, weight: NSFont.Weight.regular)
		progressLabel.stringValue = ""		
		
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .combinedRefreshProgressDidChange, object: nil)
	}

	@objc func updateUI() {

		updateProgressIndicator()
		updateProgressLabel()
	}

	// MARK: Notifications

	@objc dynamic func progressDidChange(_ notification: Notification) {

		CoalescingQueue.standard.add(self, #selector(updateUI))
	}
}

private extension SidebarStatusBarView {

	// MARK: Progress

	static let animationDuration = 0.2

	func stopProgressIfNeeded() {

		if !isAnimatingProgress {
			return
		}
		isAnimatingProgress = false
		progressIndicator.stopAnimation(self)
		progressIndicator.isHidden = true
		progressLabel.isHidden = true

		superview?.layoutSubtreeIfNeeded()

		NSAnimationContext.runAnimationGroup { context in
			context.duration = SidebarStatusBarView.animationDuration
			context.allowsImplicitAnimation = true
			bottomConstraint.constant = -(heightConstraint.constant)
			superview?.layoutSubtreeIfNeeded()
		}
	}

	func startProgressIfNeeded() {

		if isAnimatingProgress {
			return
		}
		isAnimatingProgress = true
		progressIndicator.isHidden = false
		progressLabel.isHidden = false
		progressIndicator.startAnimation(self)

		superview?.layoutSubtreeIfNeeded()

		NSAnimationContext.runAnimationGroup { context in
			context.duration = SidebarStatusBarView.animationDuration
			context.allowsImplicitAnimation = true
			bottomConstraint.constant = 0
			superview?.layoutSubtreeIfNeeded()
		}
	}

	func updateProgressIndicator() {

                let refresh = AccountManager.shared.combinedRefreshProgress
                let extraction = AccountManager.shared.combinedArticleExtractionProgress

                let totalTasks = refresh.numberOfTasks + extraction.numberOfTasks
                let totalCompleted = refresh.numberCompleted + extraction.numberCompleted

                if totalTasks == 0 {
                        stopProgressIfNeeded()
                        return
                }

                startProgressIfNeeded()

                if progressIndicator.maxValue != Double(totalTasks) {
                        progressIndicator.maxValue = Double(totalTasks)
                }
                if progressIndicator.doubleValue != Double(totalCompleted) {
                        progressIndicator.doubleValue = Double(totalCompleted)
                }
        }

        func updateProgressLabel() {

                let refresh = AccountManager.shared.combinedRefreshProgress
                let extraction = AccountManager.shared.combinedArticleExtractionProgress

                let totalTasks = refresh.numberOfTasks + extraction.numberOfTasks
                let totalCompleted = refresh.numberCompleted + extraction.numberCompleted

                if totalTasks == 0 {
                        progressLabel.stringValue = ""
                        return
                }

                let formatString = NSLocalizedString("%@ of %@", comment: "Status bar progress")
                let s = String(format: formatString, NSNumber(value: totalCompleted), NSNumber(value: totalTasks))

                progressLabel.stringValue = s
        }
}
