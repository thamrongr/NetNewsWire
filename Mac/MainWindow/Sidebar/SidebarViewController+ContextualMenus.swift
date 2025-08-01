//
//  SidebarViewController+ContextualMenus.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/28/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import Articles
import Account
import RSCore
import UserNotifications
import UniformTypeIdentifiers

extension Notification.Name {
	public static let DidUpdateFeedPreferencesFromContextMenu = Notification.Name(rawValue: "DidUpdateFeedPreferencesFromContextMenu")
}

extension SidebarViewController {

	func menu(for objects: [Any]?) -> NSMenu? {

		guard let objects = objects, objects.count > 0 else {
			return menuForNoSelection()
		}

		if objects.count > 1 {
			return menuForMultipleObjects(objects)
		}

		let object = objects.first!

		switch object {
		case is WebFeed:
			return menuForWebFeed(object as! WebFeed)
		case is Folder:
			return menuForFolder(object as! Folder)
		case is PseudoFeed:
			return menuForSmartFeed(object as! PseudoFeed)
		default:
			return nil
		}
	}
}

// MARK: Contextual Menu Actions

extension SidebarViewController {

	@objc func openHomePageFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		Browser.open(urlString, inBackground: false)
	}

	@objc func copyURLFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let urlString = menuItem.representedObject as? String else {
			return
		}
		URLPasteboardWriter.write(urlString: urlString, to: NSPasteboard.general)
	}

	@objc func markObjectsReadFromContextualMenu(_ sender: Any?) {

		guard let menuItem = sender as? NSMenuItem, let objects = menuItem.representedObject as? [Any] else {
			return
		}
		
		let articles = unreadArticles(for: objects)
		guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: Array(articles), markingRead: true, undoManager: undoManager) else {
			return
		}
		runCommand(markReadCommand)
	}
	
	@objc func shareAllUnreadAsReadFromContextualMenu(_ sender: Any?) {

			guard let menuItem = sender as? NSMenuItem,
				  let smartFeed = menuItem.representedObject as? PseudoFeed,
				  let unreadFeed = smartFeed as? UnreadFeed else {
					return
			}

			guard let articlesSet = try? unreadFeed.fetchUnreadArticles() else {
					return
			}

                        let articles = Array(articlesSet).sortedByDate(.orderedAscending)

                        let shareText = articles.reduce(into: "") { partial, article in
                                        if let title = article.title {
                                                        partial += "\(title)\n\n"
                                        }
                                        if let content = article.extractedArticle?.content {
                                                        partial += content.convertingToPlainText()
                                        } else if let html = article.contentHTML {
                                                        partial += html.convertingToPlainText()
                                        } else if let contentText = article.contentText {
                                                        partial += contentText
                                        }
                                        partial += "\n\n"
                        }

                        let articlesByAccount = Dictionary(grouping: articles, by: { $0.accountID })

                        var accountSaveText: [Account: String] = [:]
                        for (accountID, accountArticles) in articlesByAccount {
                                guard let account = AccountManager.shared.existingAccount(with: accountID) else { continue }
                                let text = accountArticles.reduce(into: "") { partial, article in
                                        if let title = article.title {
                                                partial += "Title: \(title)\n\n"
                                        }
									
										partial += "Content : \n\n"
                                        if article.webFeed?.isArticleExtractorTextAlwaysOn ?? false {
                                                if let content = article.extractedArticle?.content {
                                                        partial += content.convertingToPlainText()
                                                } else if let html = article.contentHTML {
                                                        partial += html.convertingToPlainText()
                                                } else if let contentText = article.contentText {
                                                        partial += contentText
                                                }
                                        } else {
                                                if let contentText = article.contentText {
                                                        partial += contentText
                                                } else if let html = article.contentHTML {
                                                        partial += html.convertingToPlainText()
                                                } else if let content = article.extractedArticle?.content {
                                                        partial += content.convertingToPlainText()
                                                }
                                        }
										partial += "\n\nurl: "
									
										if let rawLink = article.rawLink {
											partial += "\(rawLink)"
										} else if let rawExternalLink = article.rawExternalLink {
											partial += "\(rawExternalLink)"
										}
										
										partial += "\n\n\n\n"
									
                                }
                                accountSaveText[account] = text
                        }


			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Share or Save", comment: "Share or Save")
			alert.informativeText = NSLocalizedString("Do you want to share or save all unread articles?", comment: "Share or Save")
			alert.addButton(withTitle: NSLocalizedString("Share", comment: "Share"))
			alert.addButton(withTitle: NSLocalizedString("Save…", comment: "Save"))
			alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
			let response = alert.runModal()

                        if response == .alertFirstButtonReturn {
                                        let picker = NSSharingServicePicker(items: [shareText])
                                        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
                        } else if response == .alertSecondButtonReturn {
                                        let formatter = DateFormatter()
                                        formatter.timeZone = .current
                                        formatter.dateFormat = "yyyy-MM-dd"
                                        let dateString = formatter.string(from: Date())

                                        if accountSaveText.count <= 1, let (account, text) = accountSaveText.first {
                                                let panel = NSSavePanel()
                                                panel.allowedContentTypes = [UTType.plainText]
                                                let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
                                                panel.nameFieldStringValue = "AllUnread_\(dateString)_\(accountName).txt"
                                                panel.beginSheetModal(for: view.window!) { result in
                                                        if result == .OK, let url = panel.url {
                                                                try? text.write(to: url, atomically: true, encoding: .utf8)
                                                        }
                                                }
                                        } else {
                                                let panel = NSOpenPanel()
                                                panel.canChooseDirectories = true
                                                panel.canChooseFiles = false
                                                panel.allowsMultipleSelection = false
                                                panel.prompt = NSLocalizedString("Choose", comment: "Choose")
                                                panel.title = NSLocalizedString("Choose Folder", comment: "Choose Folder")
                                                panel.beginSheetModal(for: view.window!) { result in
                                                        if result == .OK, let directory = panel.url {
                                                                for (account, text) in accountSaveText {
                                                                        let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
                                                                        let fileURL = directory.appendingPathComponent("AllUnread_\(dateString)_\(accountName).txt")
                                                                        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
                                                                }
                                                        }
                                                }
                                        }
                        } else {
                                        return
                        }

			guard let undoManager = undoManager, let markReadCommand = MarkStatusCommand(initialArticles: articles, markingRead: true, undoManager: undoManager) else {
					return
			}
			runCommand(markReadCommand)
	}

	@objc func deleteFromContextualMenu(_ sender: Any?) {
		guard let menuItem = sender as? NSMenuItem, let objects = menuItem.representedObject as? [AnyObject] else {
			return
		}
		
		let nodes = objects.compactMap { treeController.nodeInTreeRepresentingObject($0) }

		let alert = SidebarDeleteItemsAlert.build(nodes)
		alert.beginSheetModal(for: view.window!) { [weak self] result in
			if result == NSApplication.ModalResponse.alertFirstButtonReturn {
				self?.deleteNodes(nodes)
			}
		}
	}

	@objc func renameFromContextualMenu(_ sender: Any?) {

		guard let window = view.window, let menuItem = sender as? NSMenuItem, let object = menuItem.representedObject as? DisplayNameProvider, object is WebFeed || object is Folder else {
			return
		}

		renameWindowController = RenameWindowController(originalTitle: object.nameForDisplay, representedObject: object, delegate: self)
		guard let renameSheet = renameWindowController?.window else {
			return
		}
		window.beginSheet(renameSheet)
	}
	
	@objc func toggleNotificationsFromContextMenu(_ sender: Any?) {
		guard let item = sender as? NSMenuItem,
			  let feed = item.representedObject as? WebFeed else {
			return
		}
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			if settings.authorizationStatus == .denied {
				self.showNotificationsNotEnabledAlert()
			} else if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					if feed.isNotifyAboutNewArticles == nil { feed.isNotifyAboutNewArticles = false }
					feed.isNotifyAboutNewArticles?.toggle()
					NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
				}
			} else {
				UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
					if granted {
						DispatchQueue.main.async {
							if feed.isNotifyAboutNewArticles == nil { feed.isNotifyAboutNewArticles = false }
							feed.isNotifyAboutNewArticles?.toggle()
							NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
							NSApplication.shared.registerForRemoteNotifications()
						}
					} else {
						self.showNotificationsNotEnabledAlert()
					}
				}
			}
		}
	}
	
        @objc func toggleArticleExtractorFromContextMenu(_ sender: Any?) {
                guard let item = sender as? NSMenuItem,
                          let feed = item.representedObject as? WebFeed else {
                        return
                }
                if feed.isArticleExtractorAlwaysOn == nil { feed.isArticleExtractorAlwaysOn = false }
                feed.isArticleExtractorAlwaysOn?.toggle()
                NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
        }

       @objc func toggleArticleExtractorTextFromContextMenu(_ sender: Any?) {
               guard let item = sender as? NSMenuItem,
                         let feed = item.representedObject as? WebFeed else {
                       return
               }
               if feed.isArticleExtractorTextAlwaysOn == nil { feed.isArticleExtractorTextAlwaysOn = false }
               feed.isArticleExtractorTextAlwaysOn?.toggle()
               NotificationCenter.default.post(Notification(name: .DidUpdateFeedPreferencesFromContextMenu))
       }
	
	func showNotificationsNotEnabledAlert() {
		DispatchQueue.main.async {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Notifications are not enabled", comment: "Notifications are not enabled.")
			alert.informativeText = NSLocalizedString("You can enable NetNewsWire notifications in System Preferences.", comment: "Notifications are not enabled.")
			alert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: "Open System Preferences"))
			alert.addButton(withTitle: NSLocalizedString("Dismiss", comment: "Dismiss"))
			let userChoice = alert.runModal()
			if userChoice == .alertFirstButtonReturn {
				let config = NSWorkspace.OpenConfiguration()
				config.activates = true
				// If System Preferences is already open, and no delay is provided here, then it appears in the foreground and immediately disappears.
				DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.2, execute: {
					NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!, configuration: config)
				})
			}
		}
	}
	
}

extension SidebarViewController: RenameWindowControllerDelegate {

	func renameWindowController(_ windowController: RenameWindowController, didRenameObject object: Any, withNewName name: String) {

		if let feed = object as? WebFeed {
			feed.rename(to: name) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		} else if let folder = object as? Folder {
			folder.rename(to: name) { result in
				switch result {
				case .success:
					break
				case .failure(let error):
					NSApplication.shared.presentError(error)
				}
			}
		}
	}
}

// MARK: Build Contextual Menus

private extension SidebarViewController {

	func menuForNoSelection() -> NSMenu {

		let menu = NSMenu(title: "")

		menu.addItem(withTitle: NSLocalizedString("New Feed", comment: "Command"), action: #selector(AppDelegate.showAddWebFeedWindow(_:)), keyEquivalent: "")
		menu.addItem(withTitle: NSLocalizedString("New Folder", comment: "Command"), action: #selector(AppDelegate.showAddFolderWindow(_:)), keyEquivalent: "")

		return menu
	}

	func menuForWebFeed(_ webFeed: WebFeed) -> NSMenu? {

		let menu = NSMenu(title: "")

		if webFeed.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([webFeed]))
			menu.addItem(NSMenuItem.separator())
		}

		if let homePageURL = webFeed.homePageURL, let _ = URL(string: homePageURL) {
			let item = menuItem(NSLocalizedString("Open Home Page", comment: "Command"), #selector(openHomePageFromContextualMenu(_:)), homePageURL)
			menu.addItem(item)
			menu.addItem(NSMenuItem.separator())
		}

		let copyFeedURLItem = menuItem(NSLocalizedString("Copy Feed URL", comment: "Command"), #selector(copyURLFromContextualMenu(_:)), webFeed.url)
		menu.addItem(copyFeedURLItem)

		if let homePageURL = webFeed.homePageURL {
			let item = menuItem(NSLocalizedString("Copy Home Page URL", comment: "Command"), #selector(copyURLFromContextualMenu(_:)), homePageURL)
			menu.addItem(item)
		}
		menu.addItem(NSMenuItem.separator())
		
		let notificationText = webFeed.notificationDisplayName.capitalized
		
		let notificationMenuItem = menuItem(notificationText, #selector(toggleNotificationsFromContextMenu(_:)), webFeed)
		if webFeed.isNotifyAboutNewArticles == nil || webFeed.isNotifyAboutNewArticles! == false {
			notificationMenuItem.state = .off
		} else {
			notificationMenuItem.state = .on
		}
		menu.addItem(notificationMenuItem)

                let articleExtractorText = NSLocalizedString("Always Use Reader View", comment: "Always Use Reader View")
                let articleExtractorMenuItem = menuItem(articleExtractorText, #selector(toggleArticleExtractorFromContextMenu(_:)), webFeed)

                if webFeed.isArticleExtractorAlwaysOn == nil || webFeed.isArticleExtractorAlwaysOn! == false {
                        articleExtractorMenuItem.state = .off
                } else {
                        articleExtractorMenuItem.state = .on
                }
                menu.addItem(articleExtractorMenuItem)

               let textExtractorText = NSLocalizedString("Always Extract Text", comment: "Always Extract Text")
               let textExtractorMenuItem = menuItem(textExtractorText, #selector(toggleArticleExtractorTextFromContextMenu(_:)), webFeed)

               if webFeed.isArticleExtractorTextAlwaysOn == nil || webFeed.isArticleExtractorTextAlwaysOn! == false {
                       textExtractorMenuItem.state = .off
               } else {
                       textExtractorMenuItem.state = .on
               }
               menu.addItem(textExtractorMenuItem)

		menu.addItem(NSMenuItem.separator())
		
		menu.addItem(renameMenuItem(webFeed))
		menu.addItem(deleteMenuItem([webFeed]))

		return menu
	}

	func menuForFolder(_ folder: Folder) -> NSMenu? {

		let menu = NSMenu(title: "")

		if folder.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([folder]))
			menu.addItem(NSMenuItem.separator())
		}

		menu.addItem(renameMenuItem(folder))
		menu.addItem(deleteMenuItem([folder]))

		return menu.numberOfItems > 0 ? menu : nil
	}

	func menuForSmartFeed(_ smartFeed: PseudoFeed) -> NSMenu? {

		let menu = NSMenu(title: "")

		if smartFeed.unreadCount > 0 {
			menu.addItem(markAllReadMenuItem([smartFeed]))
			if smartFeed is UnreadFeed {
					menu.addItem(shareAllUnreadMenuItem(smartFeed))
			}
		}
		return menu.numberOfItems > 0 ? menu : nil
	}

	func menuForMultipleObjects(_ objects: [Any]) -> NSMenu? {

		let menu = NSMenu(title: "")

		if anyObjectInArrayHasNonZeroUnreadCount(objects) {
			menu.addItem(markAllReadMenuItem(objects))
		}

		if allObjectsAreFeedsAndOrFolders(objects) {
			menu.addSeparatorIfNeeded()
			menu.addItem(deleteMenuItem(objects))
		}

		return menu.numberOfItems > 0 ? menu : nil
	}

	func markAllReadMenuItem(_ objects: [Any]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Mark All as Read", comment: "Command"), #selector(markObjectsReadFromContextualMenu(_:)), objects)
	}
	
	func shareAllUnreadMenuItem(_ object: Any) -> NSMenuItem {
			return menuItem(NSLocalizedString("Share All as Read", comment: "Command"), #selector(shareAllUnreadAsReadFromContextualMenu(_:)), object)
	}
	
	func deleteMenuItem(_ objects: [Any]) -> NSMenuItem {

		return menuItem(NSLocalizedString("Delete", comment: "Command"), #selector(deleteFromContextualMenu(_:)), objects)
	}

	func renameMenuItem(_ object: Any) -> NSMenuItem {

		return menuItem(NSLocalizedString("Rename", comment: "Command"), #selector(renameFromContextualMenu(_:)), object)
	}

	func anyObjectInArrayHasNonZeroUnreadCount(_ objects: [Any]) -> Bool {

		for object in objects {
			if let unreadCountProvider = object as? UnreadCountProvider {
				if unreadCountProvider.unreadCount > 0 {
					return true
				}
			}
		}
		return false
	}

	func allObjectsAreFeedsAndOrFolders(_ objects: [Any]) -> Bool {

		for object in objects {
			if !objectIsFeedOrFolder(object) {
				return false
			}
		}
		return true
	}

	func objectIsFeedOrFolder(_ object: Any) -> Bool {

		return object is WebFeed || object is Folder
	}

	func menuItem(_ title: String, _ action: Selector, _ representedObject: Any) -> NSMenuItem {

		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.representedObject = representedObject
		item.target = self
		return item
	}

	func unreadArticles(for objects: [Any]) -> Set<Article> {

		var articles = Set<Article>()
		for object in objects {
			if let articleFetcher = object as? ArticleFetcher {
				if let unreadArticles = try? articleFetcher.fetchUnreadArticles() {
					articles.formUnion(unreadArticles)
				}
			}
		}
		return articles
	}
}

